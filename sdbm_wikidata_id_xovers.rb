#!/usr/bin/env ruby

require 'erb'
require 'csv'
require 'cgi'
require 'faraday'

# Template for the SPARQL query
template = ERB.new <<-EOF
SELECT DISTINCT ?otherid ?otheridName ?item ?itemLabel
WHERE
{
  BIND("<%= other_id_name %>" as ?otheridName)
  ?item wdt:<%= other_id %> ?otherid.
  ?item wdt:P9756 ?schoe .
  #?item wdt:P9943 ?hmml .
  ?item wdt:P31 wd:Q5 .
  SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
}
EOF

# Expect an input CSV with these columns
#
# prop,propLabel,count,total humans with ID,SDBM is % of total,Reviewer(s),Query,Thoughts
# http://www.wikidata.org/entity/P4230,"""Sefaria ID""@en",6,6,100.00,,,


# Setup
#
# Install Ruby (this script was run on Ruby 3.2.2)
# Install the Faraday gem
#
#   gem install faraday


# Usage:
#
#   ruby sdbm_wikidata_id_xovers.rb sdbm_and_other_props.csv > output.csv

# get the input CSV
input_csv = ARGV.shift

url = 'https://query.wikidata.org/sparql'

headers = %w{prop otheridName item itemLabel }
# Create a CSV that outputs to the terminal
CSV headers: true do |csv|
  # add the headers to the the output CSV
  csv << headers

  CSV.foreach input_csv, headers: true do |row|
    break unless row['prop']
    next if row['count'].to_i < 1
    # assign the prop number and the property label to
    # other_id and other_id_name; this binds those values
    # to the variables called in the template
    other_id      = row['prop'].split(%r{/}).pop
    other_id_name = row['propLabel'].chomp('@en').delete('"')
    query         = template.result binding

    # call the query service with the query and ask for CSV
    response      = Faraday.get(
      url, { query: query }, { 'Accept' => 'text/csv' }
    )

    # cycle through the results and add each row of the
    # output CSV
    CSV.parse response.body, headers: true do |result_row|
      csv << result_row.to_h.merge('prop' => other_id)
    end
  end
end