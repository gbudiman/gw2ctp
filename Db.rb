class Db
	def initialize
		@dbh = open_databse
		@dbh.results_as_hash = true
		create_table
	end

	def create_table
		@dbh.execute "CREATE TABLE IF NOT EXISTS Items(
				id INTEGER PRIMARY KEY,
				name TEXT,
				level INTEGER,
				rarity TEXT,
				type_id INTEGER
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS Types(
				id INTEGER PRIMARY KEY,
				name TEXT
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS Market(
				id INTEGER PRIMARY KEY,
				item_id INTEGER,
				buy_count INTEGER,
				buy_price INTEGER,
				sell_count INTEGER,
				sell_price INTEGER,
				time INTEGER
			)"
		@dbh.execute "CREATE TABLE IF NOT EXISTS Crafting(
				id INTEGER PRIMARY KEY,
				final_id INTEGER,
				comp_id INTEGER,
				comp_amt INTEGER
			)"
	end

	def get_crafting_data
		return @dbh.execute '
			SELECT Crafting.final_id AS target_id
				, FinalItem.name AS target_name
				, Crafting.comp_id AS comp_id
				, CompItem.name AS comp_name
				, Crafting.comp_amt AS comp_amt
				FROM Crafting 
				INNER JOIN Items AS FinalItem
					ON Crafting.final_id = FinalItem.id				
				INNER JOIN Items AS CompItem
					ON Crafting.comp_id = CompItem.id
			'
	end

	def get_crafting_item_types
		return @dbh.execute '
			SELECT Types.id AS type_id
				, Types.name AS name
				FROM
				(SELECT DISTINCT Items.type_id
					FROM Crafting
					INNER JOIN Items
						ON Crafting.final_id = Items.id
				UNION
				SELECT DISTINCT Items.type_id
					FROM Crafting
					INNER JOIN Items
						ON Crafting.comp_id = Items.id) AS t_list
				INNER JOIN Types
					ON t_list.type_id = Types.id
			'
	end

	def get_market_data
		return @dbh.execute 'SELECT * FROM Market'
	end

	def get_market_timestamp
		return @dbh.execute 'SELECT MAX(time) AS latest_time FROM Market'
	end

	def get_rows
		return @dbh.execute("SELECT id, name FROM Items")
	end

	def open_databse
		return SQLite3::Database.open 'gw2tp.db'
	end

	def truncate_crafting_table
		@dbh.execute "DELETE FROM Crafting"
	end

	def truncate_market_table
		@dbh.execute "DELETE FROM Market"
	end

	def update_rows _table, _h
		case _table
		when :crafting
			x = @dbh.prepare("INSERT INTO Crafting (
					final_id, comp_id, comp_amt
				) VALUES(?, ?, ?)")

			_h.each do |d|
				x.execute(d['final_id'],
					d['comp_id'], 
					d['comp_amt'])
			end
		when :item_lists
			x = @dbh.prepare("INSERT OR REPLACE INTO Items VALUES(
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
			x = @dbh.prepare("INSERT INTO Market (
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
		when :types
			x = @dbh.prepare("INSERT OR REPLACE INTO Types VALUES(
				?, ?)")

			_h.each do |key, data|
				x.execute(key, data['name'])
			end
		end
	end
end