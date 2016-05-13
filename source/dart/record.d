
module dart.record;

import std.array;
import std.format;

public import std.conv;
public import std.traits;
public import std.variant;

//public import mysql.db;
import db.database;

public import dart.query;
public import dart.helpers.attributes;
public import dart.helpers.helpers;

version(USE_MYSQL)
{
	import db.driver.mysql;
	alias MySql Connection;
}

/**
 * Exception type produced by record operations.
 **/
class RecordException : Exception {

    /**
     * Constructs a record exception with an error message.
     **/
    this(string message) {
        super(message);
    }

}

/**
 * A container type for Record information.
 **/
struct RecordData(T) {

    /**
     * The name of the corresponding table.
     **/
    string table;

    /**
     * The name of the primary id column.
     **/
    string idColumn;

    /**
     * The column info table, for this record type.
     **/
    ColumnBindings[string] columns;

    /**
     * Mysql database connection.
     **/
    Connection dbConnection;

}

/**
 * The record class type.
 *
 * Template argument ensures that static fields stay local
 * to the template instance (and thus, to the Record itself).
 **/
class Record(Type) {

	
    private static {

        /**
         * A container for static Record information.
         **/
        RecordData!Type _recordData;

    }

    protected static {

        /**
         * Gets a column definition, by name.
         **/
        ColumnBindings getColumnBindings(string name) {
            return _recordData.columns[name];
        }

        /**
         * Adds a column definition to this record.
         **/
        void addColumnBindings(ColumnBindings ci) {
            _recordData.columns[ci.name] = ci;
        }

        /**
         * Gets the name of the Id column.
         **/
        string getIdColumn() {
            return _recordData.idColumn;
        }

        /**
         * Sets the name of the Id column.
         **/
        void setIdColumn(string column) {
            _recordData.idColumn = column;
        }

        /**
         * Gets the name of the table for this record.
         **/
        string getTableName() {
            return _recordData.table;
        }

        /**
         * Sets the name of the table for this record.
         **/
        void setTableName(string table) {
            _recordData.table = table;
        }

        /**
         * Gets the column list for this record.
         **/
        string[] getColumnNames() {
            return _recordData.columns.keys;
        }

        /**
         * Gets a list of column values, for this instance.
         **/
        Variant[] getColumnValues(T)(T instance) {
            Variant[] values;
            foreach(name, info; _recordData.columns)
                values ~= info.get(instance);
            return values;
        }

        /**
         * Gets the database connection.
		 * 获取连接
         **/
        Connection getDBConnection() {
            // Mysql-native provides this.
            version(USE_MYSQL) {
                if(_recordData.dbConnection !is null) {
                    return _recordData.dbConnection;
                }
            }

            // No database connection set.
            throw new RecordException("Record has no database connection.");
        }

        /**
         * Sets the database connection.
         **/
        void setDBConnection(Connection conn) {
            _recordData.dbConnection = conn;
        }

        // Mysql-native provides this.
		//version(Have_vibe_d) {
		//    /**
		//     * Sets the database connection.
		//     **/
		//    void setDBConnection(MysqlDB db) {
		//        _recordData.mysqlConnection = db;
		//    }
		//}

        /**
         * Executes a query that produces a result set.
         **/
        ResultSet executeQueryResult(QueryBuilder query) {
            // Get a database connection.
			auto conn = getDBConnection;
			//auto command = Command(conn);
			//
			//// Prepare the query.
			string sql = query.build;
			ResultSet result ;
			try
			{
				result = conn.query(sql);
				std.stdio.writeln("query result getThreadId:", conn.getThreadId());
			}
			catch(Exception e)
			{
				std.stdio.writeln("query error!Line: ",__LINE__);
			}
			//command.prepare;
			//
			//// Bind parameters and execute.
			//command.bindParameters(query.getParameters);
			//return command.execPreparedResult;
			return result;
        }

        /**
         * Executes a query that doesn't produce a result set.
		 * 返回查询结果 的长度
         **/
        ulong executeQuery(QueryBuilder query) {
            // Get a database connection.
			auto conn = getDBConnection;
			//auto command = Command(conn);
			
			string sql = query.build;
			auto queryRes = conn.query(sql);
			std.stdio.writeln("query getThreadId:", conn.getThreadId());
			//
			//// Prepare the query.
			//command.sql = query.build;
			//command.prepare;0
			//
			//// Bind parameters and execute.
			//command.bindParameters(query.getParameters);
			//command.execPrepared(result);
			
            return queryRes.length();
        }

        /**
         * Gets the query for get() operations.
         **/
        QueryBuilder getQueryForGet(KT)(KT key) {
            SelectBuilder builder = new SelectBuilder()
                    .select(getColumnNames).from(getTableName).limit(1);
            return builder.where(new WhereBuilder().equals(getIdColumn, key));
        }

        /**
         * Gets the query for find() operations.
         **/
        QueryBuilder getQueryForFind(KT)(KT[string] conditions, int limit) {
            auto query = appender!string;
            SelectBuilder builder = new SelectBuilder()
                    .select(getColumnNames).from(getTableName).limit(limit);
			
			WhereBuilder whereBuilder = new WhereBuilder();
            //formattedWrite(query, "%-(`%s`=?%| AND %)", conditions.keys);
			int i=0;
			foreach(key, value; conditions)
			{
				whereBuilder.equals(key, value);
				if(i != conditions.length-1)
				{
					whereBuilder.and();
				}
				
				
				i++;
			}
            return builder.where(whereBuilder);
        }

        /**
         * Gets the query for create() operations.
         **/
        QueryBuilder getQueryForCreate(T)(T instance) {
            InsertBuilder builder = new InsertBuilder()
                    .insert(getColumnNames).into(getTableName);

            // Add column values to query.
            foreach(string name; getColumnNames) {
				std.stdio.writeln(name);
                auto info = getColumnBindings(name);
				//std.stdio.writeln(info.get(instance));
                builder.value(info.get(instance));
            }

            return builder;
        }

        /**
         * Gets the query for update() operations.
         **/
        QueryBuilder getQueryForSave(T)(
                T instance, string[] columns = null...) {
            UpdateBuilder builder = new UpdateBuilder()
                    .update(getTableName).limit(1);

            // Check for a columns list.
            if(columns is null) {
                // Include all columns.
                columns = getColumnNames;
            }

            // Set column values in query.
            foreach(string name; columns) {
                auto info = getColumnBindings(name);
                builder.set(info.name, info.get(instance));
            }

            // Update the record using the primary id.
            Variant id = getColumnBindings(getIdColumn).get(instance);
			//std.stdio.writeln(id);
            return builder.where(new WhereBuilder().equals(getIdColumn, id));
        }

        /**
         * Gets the query for remove() operations.
         **/
        QueryBuilder getQueryForRemove(T)(T instance) {
            DeleteBuilder builder = new DeleteBuilder()
                    .from(getTableName).limit(1);

            // Delete the record using the primary id.
            Variant id = getColumnBindings(getIdColumn).get(instance);
            return builder.where(new WhereBuilder().equals(getIdColumn, id));
        }

    }

}

/**
 * The ActiveRecord mixin.
 **/
mixin template ActiveRecord() {

    /**
     * Alias to the local type.
	 * alias Target(alias T) = T;
     **/
    alias Type = Target!(__traits(parent, get));

    /**
     * Static initializer for column info.
     **/
    static this() {
        // Check if the class defined an override name.
        setTableName(getTableDefinition!(Type));

        // Search through class members.
        foreach(member; __traits(derivedMembers, Type)) {
            static if(__traits(compiles, __traits(getMember, Type, member))) {
                alias Current = Target!(__traits(getMember, Type, member));

                // Check if this is a column.
                static if(isColumn!(Type, member)) {
                    // Ensure that this isn't a function.
                    static assert(!is(typeof(Current) == function));

                    // Find the column name.
                    string name = getColumnDefinition!(Type, member);

                    // Create a column info record.
                    auto info = new ColumnBindings();
                    info.field = member;
                    info.name = name;

                    // Create delegate get and set.
                    info.get = createGetDelegate!(Type, member)(info);
                    info.set = createSetDelegate!(Type, member)(info);

                    // Populate other fields.
                    foreach(annotation; __traits(getAttributes, Current)) {
                        // Check is @Id is present.
                        static if(is(annotation == Id)) {
                            // Check for duplicate Id.
                            if(getIdColumn !is null) {
                                throw new RecordException(Type.stringof ~
                                        " already defined an Id column.");
                            }

                            // Save the Id column.
                            setIdColumn(info.name);
                            info.isId = true;
                        }
                        // Check if @Nullable is present.
                        static if(is(annotation == Nullable)) {
                            info.notNull = false;
                        }
                        // Check if @AutoIncrement is present.
                        static if(is(annotation == AutoIncrement)) {
                            // Check that this can be auto incremented.
                            static assert(isNumeric!(typeof(Current)));

                            info.autoIncrement = true;
                        }
                        // Check if @MaxLength(int) is present.
                        static if(is(typeof(annotation) == MaxLength)) {
                            info.maxLength = annotation.maxLength;
                        }
                    }

                    // Store the column definition.
                    addColumnBindings(info);
                }
            }
        }

        // Check is we have an Id.
        if(getIdColumn is null) {
            throw new RecordException(Type.stringof ~
                    " doesn't define an Id column.");
        }

        // Check if we have any columns.
        if(getColumnNames.length < 1) {
            throw new RecordException(Type.stringof ~
                    " defines no valid columns.");
        }
    }

    /**
     * Gets an object by its primary key.
     **/
    static Type get(KT)(KT key) {
        // Get the query for the operation.
		auto query = getQueryForGet(key);
		// Execute the get() query.
		auto result = executeQueryResult(query);

		// Check that we got a result.
		if(result.empty) {
			throw new RecordException("No records found for " ~
					getTableName ~ " at " ~ to!string(key));
		}
	   // auto row = result.front();//result[0];
		string[string] colKeyValue=result.front().toAA();
		std.stdio.writeln("colKeyValue", colKeyValue);
        auto instance = new Type;

		//// Bind column values to fields.
		foreach(name, value; colKeyValue) {
			//auto value = row[idx];
			//variant
			getColumnBindings(name).set(instance, Variant(value));
		}

        // Return the instance.
        return instance;
    }

    /**
     * Finds matching objects, by column values.
     **/
    static Type[] find(KT)(KT[string] conditions, int limit = -1) {
        // Get the query for the operation.
        auto query = getQueryForFind(conditions, limit);
        // Execute the find() query.
        ResultSet result = executeQueryResult(query);

        // Check that we got a result.
        if(result.empty) return [];

		version(USE_MYSQL)
		{
			import db.driver.mysql;
			result = cast(MySqlResult)result;
		}

        Type[] array;
		////// Create the initial array of elements.
		//for(int i = 0; i < result.length; i++) {
		//    auto row = result[i];
		//    auto instance = new Type;
		//
		//    foreach(int idx, string name; result.colNames) {
		//        auto value = row[idx];
		//        getColumnBindings(name).set(instance, value);
		//    }
		//
		//    // Append the object.
		//    array ~= instance;
		//}
		while(!result.empty)
		{
			auto instance = new Type;
			auto row = result.front;
			foreach(string name, string value; row.toAA) {
				getColumnBindings(name).set(instance, Variant(value));
			}

			result.popFront();

			array ~= instance;
		}
		
        // Return the array.
        return array;
    }

    /**
     * Creates this object in the database, if it does not yet exist.
     **/
    void create() {
        // Get the query for the operation.
        QueryBuilder query = getQueryForCreate(this);

        // Execute the create() query.
        ulong result = executeQuery(query);
		
        // Update auto increment columns.
        auto info = getColumnBindings(getIdColumn);
        if(info.autoIncrement) {
            // Fetch the last insert id.
            query = dart.query.SelectBuilder.lastInsertId;
            ResultSet id = executeQueryResult(query);
			Row rowFront = id.front();
			import std.variant;
			Variant vt;
			foreach(string key, string item; rowFront)
			{
				if(key == "LAST_INSERT_ID()")
				{
					vt = item;
					continue;
				}
			}
            // Update the auto incremented column.
            info.set(this, vt); 
        }
    }

    /**
     * Saves this object to the database, if it already exists.
     * Optionally specifies a list of columns to be updated.
     **/
    void save(string[] names = null...) {
        // Get the query for the operation.
        auto query = getQueryForSave(this, names);

		std.stdio.writeln(query.build);
        // Execute the save() query.
		executeQuery(query);

        // Check that something was created.
		//if(result < 1) {
		//    throw new RecordException("No records were updated for " ~
		//            Type.stringof ~ " by save().");
		//}
    }

    /**
     * Removes this object from the database, if it already exists.
     **/
    void remove() {
        // Get the query for the operation.
        auto query = getQueryForRemove(this);

        // Execute the remove() query.
		executeQuery(query);
		//std.stdio.writeln("remove query type:", typeid(query));
		//std.stdio.writeln("remove query:", query.build());
      
    }

}

alias Target(alias T) = T;
