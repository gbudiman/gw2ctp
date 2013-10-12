class Crafting
	attr_accessor :craft

	def initialize
		@craft = Hash.new
		@market = Hash.new
		@timestamp = 0
	end

	def dump
		File.open('a.dat', 'w') do |file|
			Marshal.dump(@craft, file);
		end
	end

	def self.load
		File.open('a.dat', 'r') do |file|
			Marshal.load file
		end
	end

	def populate _h, _m, _t
		structurize_market_data _m
		structurize_crafting_data _h
		@timestamp = _t[0]['latest_time']

		@craft.each do |xid, row|
			crafting_cost = 0
			row['component'].each do |id, comp|
				t = comp['market_data'][@timestamp]['sell_price'] || 0
				t *= comp['component_amount']
				crafting_cost += t
			end
			row['crafting_cost'] = crafting_cost
			if (row['market_data'] != nil and 
				row['market_data'][@timestamp] != nil)
				row['profit_if_crafted'] = 
					(row['market_data'][@timestamp]['sell_price'] || 0) -
						crafting_cost
			else
				row['profit_if_crafted'] = -crafting_cost
			end
		end

		return self
	end

	private
		def structurize_crafting_data _h
			_h.each do |row|
				if @craft[row['target_id']] == nil
					@craft[row['target_id']] = {
						'target_name'		=> row['target_name'],
						'market_data'		=> @market[row['target_id']],
						'component'			=> Hash.new
					}
				end

				@craft[row['target_id']]['component'][row['comp_id']] = {
					'target_name'			=> row['comp_name'],
					'market_data'			=> @market[row['comp_id']],
					'component_amount'		=> row['comp_amt'].to_i,
				}
			end
		end

		def structurize_market_data _m
			_m.each do |row|
				if @market[row['item_id']] == nil
					@market[row['item_id']] = Hash.new
				end

				@market[row['item_id']][row['time']] = {
					'buy_count'		=> row['buy_count'],
					#'buy_price'		=> row['buy_price'],
					'sell_count'	=> row['sell_count'],
					'sell_price'	=> row['sell_price']
				}
			end
		end
end