require "timeout"
require "net/http"
require "nokogiri"
require "pry"

class WebCrawler
  MAX_NUM_THREADS            = 20
  TIME_OUT_SECONDS           = 10
  TOTAL_EXECUTION_TIME_LIMIT = 120

  attr_reader :root_url, :begin_time, :end_time
  attr_accessor :links, :success_links, :failed_links, :timed_out_links, :invalid_links,
                :forbidden_links, :exception_links

  def initialize(url)
    @root_url        = url
    @links           = []
    @success_links   = []
    @failed_links    = []
    @timed_out_links = []
    @invalid_links   = []
    @forbidden_links = []
    @exception_links = []
  end

  def run
    @begin_time = Time.now

    analyze(root_url)

    @end_time = Time.now

    print_result
  end

  private

  def analyze(root_url)
    threads          = []
    link_count       = 0
    label_a_elements = Nokogiri::HTML(open_url(root_url).body).xpath("//a")


    label_a_elements.each do |label|
      loop do
        break if Thread.list.size < MAX_NUM_THREADS

        sleep 1
      end

      href_value = label.attributes["href"]&.value

      next if href_value.nil? # some <a> doesn't have href attribute

      link_count += 1

      threads << Thread.new(href_value) do |href|
        links << href

        # for local urls
        href.prepend(root_url) unless href.start_with?("http://", "https://")

        check_availability(href)
      end
    end

    Timeout.timeout(TOTAL_EXECUTION_TIME_LIMIT) do
      loop do
        break if success_links.size + failed_links.size >= link_count

        sleep 1
      end
    end

    threads.each(&:kill)
  end

  def open_url(url)
    Timeout.timeout(TIME_OUT_SECONDS) { Net::HTTP.get_response(URI(url)) }
  end

  def check_availability(href)
    response = open_url(href)

    case response
    when Net::HTTPSuccess
      success_links << href
    when Net::HTTPForbidden
      forbidden_links << href
      failed_links << href
    when Net::HTTPMovedPermanently, Net::HTTPFound
      invalid_links << href
      failed_links << href
    else
      failed_links << href
    end
  rescue URI::InvalidURIError
    invalid_links << href
    failed_links << href
  rescue Timeout::Error
    timed_out_links << href
    failed_links << href
  rescue StandardError => e
    puts e.message
    puts e.backtrace

    exception_links << href
    failed_links << href
  end

  def print_result
    puts "Analysis on #{root_url}:"
    puts "Found #{links.size} links in total"
    puts "Success: #{success_links.size}"
    puts "Failed: #{failed_links.size}"

    puts "Access denied: #{forbidden_links.size}" unless forbidden_links.empty?
    puts "Time out: #{timed_out_links.size}" unless timed_out_links.empty?
    puts "Invalid link: #{invalid_links.size}" unless invalid_links.empty?
    puts "Exception when visited: #{exception_links.size}" unless exception_links.empty?

    time = end_time - begin_time
    min  = time.to_i / 60
    sec  = time.to_i - min * 60
    msec = ((time - time.to_i) * 1000).to_i

    puts "Time used：#{min} m #{sec} s #{msec} ms"
  end
end

begin
  if ARGV[0].nil?
    puts "please give a website url. E.g. ruby web_crawler.rb https://www.stuff.co.nz/"
    exit(1)
  end

  web_crawler = WebCrawler.new(ARGV[0])
  web_crawler.run
rescue StandardError => e
  puts e.message
  puts e.backtrace.join("\n")
end
