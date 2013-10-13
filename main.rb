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
	opt :perform_query, 'Perform query', :default => -1,	:short => :q
	opt :list_by_profit, 'List crafting profit', :default => 0x80000000,
		:short => :l
end

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


if opts[:list_by_profit] != 0x80000000
	i = -1
	p = 10
	D.get_crafting_profit.each do |x|
		i += 1
		next unless i >= opts[:list_by_profit] * p and
			i < (opts[:list_by_profit] + 1) * p
		pp x
	end
end

if opts[:perform_query] != -1
	D.get_crafting_dependency(opts[:perform_query]).each do |x|
		pp x
	end
end