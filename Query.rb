require 'json'
require 'net/http'

class Query
	def self.get_item_types
		data = Hash.new
		t = JSON.parse Net::HTTP.get('gw2tp.net', '/api/v1/item_types')
		t.each do |element|
			data[element['id']] = {
				'name'		=> element['name']
			}

			if element['sub_types'] != nil
				element['sub_types'].each do |subt|
					data[subt['id']] = {
						'name'		=> subt['name']
					}
				end
			end
		end

		return data
	end

	def self.get_item_lists
		data = Hash.new
		page = 1
		loop do
			t = JSON.parse Net::HTTP.get('gw2tp.net', "/api/v1/items/?page=#{page}")
			break if t['items'] == nil
			page += 1

			t['items'].each do |item|
				data[item['id']] = {
					'name'		=> item['name'],
					'level'		=> item['level'],
					'rarity'	=> item['rarity'],
					'type_id'	=> item['item_type']['id']
				}
			end
		end

		return data
	end

	def self.get_item_price _a
		data = Array.new
		timestamp = Time.now.to_time.to_i
		_a.each do |e|
			page = 1
			loop do
				address = "/api/v1/items/?item_type=#{e['type_id']}&page=#{page}"
				t = JSON.parse Net::HTTP.get('gw2tp.net', address)
				break if t['items'] == nil
				puts address
				page += 1

				t['items'].each do |item|
					data.push({
						'id'			=> item['id'],
						'buy_count'		=> item['buy_count'],
						'sell_count'	=> item['sell_count'],
						'buy_price'		=> item['buy_price'],
						'sell_price'	=> item['sell_price'],
						'time'			=> timestamp
					})
				end
			end
		end
		return data
	end

	def self.get_total_items
		t = JSON.parse Net::HTTP.get('gw2tp.net', "/api/v1/items/?page=999")
		return t['total_items']
	end

	def self.get_item_crafting _h
		pattern = /\<a href=\"\/items\/(\d+)\-/
		amt_pattern = /\<td\>(\d+)\<\/td\>/
		crafting_data = Array.new

		_h.each do |data|
			address = "/items/#{data['id']}"

			puts address
			t = Net::HTTP.get('gw2tp.net', address)
			amount = t.scan(amt_pattern).reverse.flatten

			t.scan(pattern).reverse.each do |id_array|
				id = id_array[0].to_i
				crafting_data.push({
						'final_id'	=> data['id'],
						'comp_id'	=> id,
						'comp_amt'	=> amount.shift
					})
			end
		end

		return crafting_data
	end
end