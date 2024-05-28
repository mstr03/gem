require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'yaml'
require 'fileutils'

def fetch_data(symbol, from_date, to_date, api_token)
  url = URI("https://eodhd.com/api/eod/#{symbol}?from=#{from_date}&to=#{to_date}&api_token=#{api_token}&fmt=json")

  request = Net::HTTP::Get.new(url)

  response = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
    http.request(request)
  end

  if response.is_a?(Net::HTTPSuccess)
    return JSON.parse(response.body)
  else
    puts "Request failed with status code: #{response.code}"
    return nil
  end
end

def calculate_percentage_change(data)
  initial_price = data.first
  final_price = data.last
  percentage_change = ((final_price - initial_price) / initial_price) * 100
  return percentage_change.round(2)
end

Dir.mkdir('./data') unless Dir.exist?('./data')

symbols = ["SPXS.LSE", "VEU.US", "IB01.LSE"]

current_month = Date.today.strftime("%m")
current_year = Date.today.strftime("%Y")

to_date = Date.today.strftime("%Y-%m-%d")
from_date_12_months = (Date.today.prev_year).strftime("%Y-%m-%d")
from_date_6_months = (Date.today.prev_month(6)).strftime("%Y-%m-%d")
from_date_3_months = (Date.today.prev_month(3)).strftime("%Y-%m-%d")

results_12_months = {}
results_6_months = {}
results_3_months = {}

symbols.each do |symbol|
  json_data_12_months = fetch_data(symbol, from_date_12_months, to_date, ARGV[0])
  data_12_months = json_data_12_months.map { |item| item["close"] }

  percentage_change_12_months = calculate_percentage_change(data_12_months)
  results_12_months[symbol] = percentage_change_12_months

  json_data_6_months = fetch_data(symbol, from_date_6_months, to_date, ARGV[0])
  data_6_months = json_data_6_months.map { |item| item["close"] }

  percentage_change_6_months = calculate_percentage_change(data_6_months)
  results_6_months[symbol] = percentage_change_6_months

  json_data_3_months = fetch_data(symbol, from_date_3_months, to_date, ARGV[0])
  data_3_months = json_data_3_months.map { |item| item["close"] }

  percentage_change_3_months = calculate_percentage_change(data_3_months)
  results_3_months[symbol] = percentage_change_3_months
end

file_paths = {
  "12_months" => "./data/percentage_change_12_months.yaml",
  "6_months" => "./data/percentage_change_6_months.yaml",
  "3_months" => "./data/percentage_change_3_months.yaml"
}

file_paths.each do |period, file_path|
  existing_data = YAML.load_file(file_path) if File.exist?(file_path)
  existing_data ||= {}

  existing_data = Hash["#{current_month}-#{current_year}", results_12_months].merge!(existing_data) if period == "12_months"
  existing_data = Hash["#{current_month}-#{current_year}", results_6_months].merge!(existing_data) if period == "6_months"
  existing_data = Hash["#{current_month}-#{current_year}", results_3_months].merge!(existing_data) if period == "3_months"

  File.open(file_path, 'w') { |file| file.write(existing_data.to_yaml) }
end
