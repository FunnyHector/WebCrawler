# WebCrawler
A simple web crawler to analyse how many links on the given url.

What it does is parse the html, find all <a> elements, try to visit the value of "href" attribute, and record the result.

## How to Run
`ruby web_crawler.rb [url]` 

For example:  
`web_crawler.rb https://www.stuff.co.nz/`
