class Db
	def initialize
		@dbh = open_database
		@dbh.results_as_hash = true
		create_table
	end

	def create_table
		@dbh.execute "CREATE TABLE IF NOT EXISTS items(
				id INTEGER PRIMARY KEY,
				name TEXT,
				level INTEGER,
				rarity TEXT,
				type_id INTEGER
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS types(
				id INTEGER PRIMARY KEY,
				name TEXT
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS markets(
				id INTEGER PRIMARY KEY,
				item_id INTEGER,
				buy_count INTEGER,
				buy_price INTEGER,
				sell_count INTEGER,
				sell_price INTEGER,
				time INTEGER
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS crafts(
				id INTEGER PRIMARY KEY,
				final_id INTEGER,
				comp_id INTEGER,
				comp_amt INTEGER
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS profits(
				id INTEGER PRIMARY KEY,
				name TEXT,
				sell_price INTEGER,
				sell_count INTEGER,
				buy_price INTEGER,
				buy_count INTEGER,
				crafting_cost INTEGER,
				crafting_profit_on_sell INTEGER,
				crafting_profit_on_buy INTEGER
			)"
		@dbh.execute "CREATE INDEX IF NOT EXISTS markets_item_id_time
				ON markets (item_id, time)"
		@dbh.execute "CREATE INDEX IF NOT EXISTS profits_by_sell
				ON profits (crafting_profit_on_sell DESC)"
		@dbh.execute "CREATE INDEX IF NOT EXISTS profits_by_buy
				ON profits (crafting_profit_on_buy DESC)"
		@dbh.execute "CREATE INDEX IF NOT EXISTS crafts_final_id
				ON crafts (final_id)"
	end

	def get_crafting_data
		return @dbh.execute '
			SELECT crafts.final_id AS target_id
				, FinalItem.name AS target_name
				, crafts.comp_id AS comp_id
				, CompItem.name AS comp_name
				, crafts.comp_amt AS comp_amt
				FROM crafts 
				INNER JOIN items AS FinalItem
					ON crafts.final_id = FinalItem.id				
				INNER JOIN items AS CompItem
					ON crafts.comp_id = CompItem.id
			'
	end

	def get_crafting_item_types
		return @dbh.execute '
			SELECT types.id AS type_id
				, types.name AS name
				FROM
				(SELECT DISTINCT items.type_id
					FROM crafts
					INNER JOIN items
						ON crafts.final_id = items.id
				UNION
				SELECT DISTINCT items.type_id
					FROM crafts
					INNER JOIN items
						ON crafts.comp_id = items.id) AS t_list
				INNER JOIN types
					ON t_list.type_id = types.id
			'
	end

	def get_crafting_dependency _id
		x = @dbh.prepare '
			SELECT crafts.final_id
				, target_item.name
				, crafts.comp_id
				, comp_item.name
				, crafts.comp_amt
				, comp_market.sell_price
				, target_market.sell_price
				, comp_market.sell_price
				, comp_market.sell_price * crafts.comp_amt
					AS crafting_cost
				FROM crafts
				INNER JOIN markets AS target_market
					ON target_market.item_id = crafts.final_id
					AND target_market.time = 
						(SELECT MAX(time) FROM markets)
				INNER JOIN items AS target_item
					ON target_item.id = crafts.final_id
				INNER JOIN markets AS comp_market
					ON comp_market.item_id = crafts.comp_id
					AND comp_market.time = 
						(SELECT MAX(time) FROM markets)
				INNER JOIN items AS comp_item
					ON comp_item.id = crafts.comp_id
				WHERE crafts.final_id = ?
			'
		return x.execute _id
	end

	def get_market_data
		return @dbh.execute 'SELECT * FROM markets'
	end

	def get_market_timestamp
		return @dbh.execute 'SELECT MAX(time) AS latest_time FROM markets'
	end

	def get_profit_data
		return @dbh.execute '
			SELECT * 
				FROM profits 
				ORDER BY crafting_profit_on_buy DESC
			'
	end

	def get_rows
		return @dbh.execute("SELECT id, name FROM items")
	end

	def open_database
		dbfile = File.dirname(__FILE__) + '/gw2ctp.db'
		return SQLite3::Database.open dbfile
	end

	def truncate_crafting_table
		@dbh.execute "DELETE FROM crafts"
	end

	def truncate_market_table
		@dbh.execute "DELETE FROM markets"
	end

	def update_rows _table, _h = Hash.new
		case _table
		when :crafting
			x = @dbh.prepare("INSERT INTO crafts (
					final_id, comp_id, comp_amt
				) VALUES(?, ?, ?)")

			_h.each do |d|
				x.execute(d['final_id'],
					d['comp_id'], 
					d['comp_amt'])
			end
		when :item_lists
			x = @dbh.prepare("INSERT OR REPLACE INTO items VALUES(
				?, ?, ?, ?, ?)")

			_h.each do |key, data|
				x.execute(key, 
					data['name'],
					data['level'],
					data['rarity'],
					data['type_id'])
			end
		when :price
			@dbh.execute 'BEGIN TRANSACTION'
			x = @dbh.prepare("INSERT INTO markets (
					item_id, buy_count, sell_count,
					buy_price, sell_price, time
				) VALUES(?, ?, ?, ?, ?, ?)")

			_h.each do |d|
				x.execute(d['id'],
					d['buy_count'],
					d['sell_count'],
					d['buy_price'],
					d['sell_price'],
					d['time'])
			end
			@dbh.execute 'COMMIT TRANSACTION'
		when :profits
			@dbh.execute 'BEGIN TRANSACTION'
			@dbh.execute 'DELETE FROM profits'
			@dbh.execute '
				INSERT INTO profits
					(id, name, sell_price, buy_price, sell_count, buy_count,
					crafting_cost, crafting_profit_on_sell, crafting_profit_on_buy)
				SELECT grouped.target_id
					, items.name
					, grouped.target_sell_price
					, grouped.target_buy_price
					, grouped.target_sell_count
					, grouped.target_buy_count
					, grouped.crafting_cost
					, grouped.crafting_profit_on_sell
					, grouped.crafting_profit_on_buy
                	FROM
	                (SELECT crafting_tree.target AS target_id
    	                , target_item.name AS target_name
        	            , crafting_tree.target_sell_price AS target_sell_price
            	        , crafting_tree.target_buy_price AS target_buy_price
                	    , crafting_tree.target_sell_count AS target_sell_count
                   		, crafting_tree.target_buy_count AS target_buy_count
	                   	, SUM(crafting_tree.crafting_cost) AS crafting_cost
    	                , crafting_tree.target_sell_price -
        	                SUM(crafting_tree.crafting_cost)
            	            AS crafting_profit_on_sell
	                    , crafting_tree.target_buy_price -
    	                    SUM(crafting_tree.crafting_cost)
        	                AS crafting_profit_on_buy
            	        FROM
                	    (SELECT crafts.final_id AS target
                    	    , crafts.comp_amt * component_market.sell_price
                        	    AS crafting_cost
	                        , target_market.sell_price AS target_sell_price
    	                    , target_market.sell_count AS target_sell_count
        	                , target_market.buy_price AS target_buy_price
            	            , target_market.buy_count AS target_buy_count
                	        FROM crafts
                    	    INNER JOIN markets AS component_market
                        	    ON component_market.item_id = crafts.comp_id
	                           	AND component_market.time = (
    	                            SELECT MAX(time) FROM markets
        	                    )
            	            INNER JOIN markets AS target_market
                	            ON target_market.item_id = crafts.final_id
                    	        AND target_market.time = (
                        	        SELECT MAX(time) FROM markets
	                            )
    	                ) AS crafting_tree
        	            INNER JOIN items AS target_item
            	            ON crafting_tree.target = target_item.id
                	    GROUP BY target_id)
	                AS grouped
					INNER JOIN items on grouped.target_id = items.id
    	            ORDER BY grouped.target_id DESC
        	    '

			@dbh.execute 'COMMIT TRANSACTION'
		when :types
			x = @dbh.prepare("INSERT OR REPLACE INTO types VALUES(
				?, ?)")

			_h.each do |key, data|
				x.execute(key, data['name'])
			end
		end
	end
end
