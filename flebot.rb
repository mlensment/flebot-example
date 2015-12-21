#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'nokogiri'

### Configuration
email = '***@***'
password = '***'
pattern = /^test$/
###

uri = URI('https://fleep.io/api/account/login')
https = Net::HTTP.new(uri.host, uri.port)
https.use_ssl = true
https.read_timeout = 3600

req = Net::HTTP::Post.new(uri.path)
req['Content-Type'] = 'application/json'
req.body = { email: email, password: password }.to_json

res = https.request(req)
if res.code != '200'
  puts 'ERROR: Login failed.'
  puts "ERROR: #{res.body}"
  exit
end

cookie = res.get_fields('set-cookie')
result = JSON.parse(res.body)
ticket = result['ticket']

poll_uri = URI('https://fleep.io/api/account/poll')
event_horizon = 0
loop do
  begin
    req = Net::HTTP::Post.new(poll_uri.path)
    req['Content-Type'] = 'application/json'
    req['Cookie'] = cookie
    req.body = { event_horizon: event_horizon, wait: true, ticket: ticket, poll_flags: ['skip_rest'] }.to_json
    res = https.request(req)
    result = JSON.parse(res.body)
    event_horizon = result['event_horizon']

    # Select only messages from the response
    messages = result['stream'].select { |x| x['mk_rec_type'] == 'message' }
    messages.each do |msg|
      next unless Nokogiri::HTML(msg['message']).text.match(pattern)
      puts "INFO: Sending message to conversation #{msg['conversation_id']}..."

      message_uri = URI("https://fleep.io/api/message/send/#{msg['conversation_id']}")
      req = Net::HTTP::Post.new(message_uri.path)
      req['Content-Type'] = 'application/json'
      req['Cookie'] = cookie
      req.body = { message: 'Message from the Flebot: Hello World!', ticket: ticket }.to_json

      res = https.request(req)
      if res.code == '200'
        puts 'INFO: Message sent.'
      else
        puts 'ERROR: Failed to send the message.'
        puts "ERROR: #{res.body}"
      end
    end
  rescue => e
    # If there is a problem with the request e.g timeout, wait for 5 seconds and then try again
    puts "DEBUG: #{e}"
    sleep 5
  end
end
