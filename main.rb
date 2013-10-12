load 'Crafting.rb'
load 'Db.rb'
load 'Query.rb'
require 'pp'
require 'sqlite3'
require 'trollop'

opts = Trollop::options do
	opt :update_item_structures, 'Update item structures', 	:short => :i
	opt :update_crafting_tree, 'Update crafting tree',		:short => :c
	opt :update_market_data, 'Update market data',			:short => :m
	opt :truncate_crafting_tree, 'Truncate crafting tree',	:short => :x
	opt :truncate_market_data, 'Truncate market data',		:short => :y
	opt :build_crafting_tree, 'Build crafting tree',		:short => :b
	opt :perform_query, 'Perform query', :default => -1,	:short => :q
	opt :list_by_profit, 'List crafting profit', :default => 0x80000000,
		:short => :l
end

C = Crafting.new
D = Db.new

if opts[:update_item_structures]
	D.update_rows :types, Query::get_item_types
	D.update_rows :item_lists, Query::get_item_lists
end

D.truncate_crafting_table if opts[:truncate_crafting_tree]
D.update_rows :crafting, Query.get_item_crafting(D.get_rows) if
	opts[:update_crafting_tree]

D.truncate_market_table if opts[:truncate_market_data]
D.update_rows :price, Query.get_item_price(D.get_crafting_item_types) if
	opts[:update_market_data]

if opts[:build_crafting_tree]
	C.populate D.get_crafting_data, D.get_market_data, D.get_market_timestamp
	C.dump
end

if opts[:list_by_profit] != 0x80000000
	x = Crafting::load
	t = D.get_market_timestamp[0]['latest_time']
	i = -1
	p = 20
	x.sort_by { |key, data| data['profit_if_crafted']
		# if data['market_data'] != nil and data['market_data'][t] != nil
		# 	(data['market_data'][t]['sell_price'] || 0) -
		# 		(data['crafting_cost'] || 0)
		# else
		# 	0
		# end
	}.reverse.each do |key, data|
		i += 1
		next unless i >= opts[:list_by_profit] * p and
			i < (opts[:list_by_profit] + 1) * p
		pp data
	end
end

if opts[:perform_query] != -1
	x = Crafting::load
	pp x[opts[:perform_query]]
end