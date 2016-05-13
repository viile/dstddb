/// NOTE: If you're using MySQL client library v5.1 or greater,
///       you must pass this to dmd: -version=MySQL_51
/// This is important - otherwise you will see bizarre segfaults!
module db.driver.mysql;

version(USE_MYSQL ):
version(MySQL_51) {
	// we good
} else version(Less_Than_MySQL_51) {
	// we good
} else
pragma(msg, "NOTE: If you are using MySQL 5.1 or newer, specify -version=MySQL_51 to dmd to avoid segfaults. If you are on an older version, you can shut this message up with -version=Less_Than_MySQL_51");

version(Windows) {
	pragma(lib, "libmysql");
}
else {
	pragma(msg,"use mysqlclient in linux");
	pragma(lib, "mysqlclient");
}

public import db.database;

import std.stdio;
import std.exception;
import std.string;
import std.conv;
import std.typecons;
import core.stdc.config;

class MySqlResult : ResultSet {
	private int[string] mapping;
	private MYSQL_RES* result;

	private int itemsTotal;
	private int itemsUsed;

	string sql;

	this(MYSQL_RES* r, string sql) {
		result = r;
		itemsTotal = length();
		itemsUsed = 0;
		this.sql = sql;

		// prime it
		if(itemsTotal)
			fetchNext();
	}

	~this() {
		if(result !is null)
			mysql_free_result(result);
	}


	MYSQL_FIELD[] fields() {
		int numFields = mysql_num_fields(result);
		auto fields = mysql_fetch_fields(result);

		MYSQL_FIELD[] ret;
		for(int i = 0; i < numFields; i++) {
			ret ~= fields[i];
		}

		return ret;
	}


	override int length() {
		if(result is null)
			return 0;
		return cast(int) mysql_num_rows(result);
	}

	override bool empty() {
		return itemsUsed == itemsTotal;
	}

	override Row front() {
		return row;
	}

	override void popFront() {
		itemsUsed++;
		if(itemsUsed < itemsTotal) {
			fetchNext();
		}
	}

	override int getFieldIndex(string field) {
		if(mapping is null)
			makeFieldMapping();
		debug {
			if(field !in mapping)
				throw new Exception(field ~ " not in result");
		}
		return mapping[field];
	}

	private void makeFieldMapping() {
		int numFields = mysql_num_fields(result);
		auto fields = mysql_fetch_fields(result);

		if(fields is null)
			return;

		for(int i = 0; i < numFields; i++) {
			if(fields[i].name !is null)
				mapping[fromCstring(fields[i].name, fields[i].name_length)] = i;
		}
	}

	private void fetchNext() {
		assert(result);
		auto r = mysql_fetch_row(result);
		if(r is null)
			throw new Exception("there is no next row");
		uint numFields = mysql_num_fields(result);
		auto lengths = mysql_fetch_lengths(result);
		string[] row;
		// potential FIXME: not really binary safe

		columnIsNull.length = numFields;
		for(int a = 0; a < numFields; a++) {
			if(*(r+a) is null) {
				row ~= null;
				columnIsNull[a] = true;
			} else {
				row ~= fromCstring(*(r+a), *(lengths +a));
				//writeln("all string------", fromCstring(*(r+a)));
				//writeln("Column  ength:------", *(lengths++));
				columnIsNull[a] = false;
			}
		}

		this.row.row = row;
		this.row.resultSet = this;
	}


	override string[] fieldNames() {
		int numFields = mysql_num_fields(result);
		auto fields = mysql_fetch_fields(result);

		string[] names;
		for(int i = 0; i < numFields; i++) {
			names ~= fromCstring(fields[i].name, fields[i].name_length);
		}

		return names;
	}



	bool[] columnIsNull;
	Row row;
}




class MySql : Database {
	///
	this(string host, string user, string pass, string db, uint port) {
		this._port = port;
		this._host = host;
		this._user = user;
		this._db = db;
		this._pass = pass;
		dbname = db;
		this.connect();
		// we want UTF8 for everything

		//query("SET NAMES 'utf8'");
		//query("SET CHARACTER SET utf8");
	}

	string dbname;
	private{
		string _host, _user, _pass, _db;
		uint _port;

	}

	private void connect()
	{
		try{
			/*mysql = enforceEx!(DatabaseException)(
			mysql_init(null),
			"Couldn't init mysql");*/
			mysql = mysql_init(null);
			//Call mysql_options() after mysql_init() and before mysql_connect() or mysql_real_connect()
			char value = 1; 
			mysql_options(mysql, mysql_option.MYSQL_OPT_RECONNECT, cast(char*)&value);
			size_t read_timeout = 60;
			mysql_options(mysql, mysql_option.MYSQL_OPT_READ_TIMEOUT, cast(size_t*)&read_timeout);
			mysql_options(mysql, mysql_option.MYSQL_OPT_WRITE_TIMEOUT, cast(size_t*)&read_timeout);

			/*enforceEx!(DatabaseException)(
			mysql_real_connect(mysql, toCstring(_host), toCstring(_user), toCstring(_pass), toCstring(_db), _port, null, 0),
			error());*/

			mysql_real_connect(mysql, toCstring(_host), toCstring(_user), toCstring(_pass), toCstring(_db), _port, null, 0);

			this.query("SET NAMES 'utf8'");
		}
		catch(DatabaseException ex)
		{
			std.stdio.writeln(error());
		}

	}

	override void startTransaction() {
		query("START TRANSACTION");
	}

	string clientInfo()
	{
		return fromCstring(mysql_get_client_info());
	}

	string error() {
		return fromCstring(mysql_error(mysql));
	}

	void close() {
		try{
			mysql_close(mysql);
		}catch(Exception ex)
		{
		}
	}

	~this() {
	}

	///ping mysql
	int pingMysql()
	{
		return mysql_ping(mysql);
	}

	///
	size_t getThreadId()
	{
		return mysql_thread_id(mysql);
	}

	public int lastInsertId() {
		return cast(int) mysql_insert_id(mysql);
	}

	int insert(string table, MySqlResult result, string[string] columnsToModify, string[] columnsToSkip) {
		assert(!result.empty);
		string sql = "INSERT INTO `" ~ table ~ "` ";

		string cols = "(";
		string vals = "(";
		bool outputted = false;

		string[string] columns;
		auto cnames = result.fieldNames;
		foreach(i, col; result.front.toStringArray) {
			bool skipMe = false;
			foreach(skip; columnsToSkip) {
				if(cnames[i] == skip) {
					skipMe = true;
					break;
				}
			}
			if(skipMe)
				continue;

			if(outputted) {
				cols ~= ",";
				vals ~= ",";
			} else
				outputted = true;

			cols ~= cnames[i];

			if(result.columnIsNull[i] && cnames[i] !in columnsToModify)
				vals ~= "NULL";
			else {
				string v = col;
				if(cnames[i] in columnsToModify)
					v = columnsToModify[cnames[i]];

				vals ~= "'" ~ escape(v) ~ "'"; 

			}
		}

		cols ~= ")";
		vals ~= ")";

		sql ~= cols ~ " VALUES " ~ vals;

		query(sql);

		result.popFront;

		return lastInsertId;
	}

	int insert(string table,  string[string] columnsToModify) {
		string sql = "INSERT INTO `" ~ table ~ "` ";

		string cols = "(";
		string vals = "(";
		bool outputted = false;

		string[string] columns;
		foreach(i, col; columnsToModify) 
		{
			if(outputted) {
				cols ~= ",";
				vals ~= ",";
			} 
			else{

				outputted = true;
			}
			cols ~= "`" ~i~ "`";
			vals ~= "'" ~ escape(col) ~ "'"; 

		}

		cols ~= ")";
		vals ~= ")";

		sql ~= cols ~ " VALUES " ~ vals;

		query(sql);
		return lastInsertId;
	}

	///更新
	int update(string table,  string[string] columnsToModify, string[string] whereCondition) {
		import std.array;
		Appender!string sql = appender!string();
		//UPDATE  `sendmsg` SET `used_time` = '%s' WHERE `id` = '%s' LIMIT 1;"
		sql.put("UPDATE  `");
		sql.put(table);
		sql.put("` SET ");
		string[] sets, wheres;
		foreach(i, col; columnsToModify) 
		{
			sets~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		foreach(i, col; whereCondition) 
		{
			wheres~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		sql.put(sets.join(", "));
		if(wheres.length != 0 )
		{
			sql.put(" WHERE ");
			sql.put(wheres.join(" AND "));
		}
		query(sql.data);
		return 1;
	}

	///删除
	int remove(string table,   string[string] whereCondition) {
		import std.array;
		Appender!string sql = appender!string();
		sql.put("DELETE FROM  `");
		sql.put(table);
		sql.put("` ");
		string[] wheres;

		foreach(i, col; whereCondition) 
		{
			wheres~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		if(wheres.length != 0 )
		{
			sql.put(" WHERE ");
			sql.put(wheres.join(" AND "));
		}
		query(sql.data);
		return 1;
	}

	///查询
	//sqlInstance.sqlClient.update("user", ["id"], ["id":"1"], 1);
	ResultSet select(string table,  string[] columnsToSelected, string[string] whereCondition, int limit = 1) {
		import std.array;
		Appender!string sql = appender!string();
		sql.put("SELECT ");
		sql.put(columnsToSelected.join(", "));
		sql.put(" FROM `");
		sql.put(table);
		sql.put("` ");

		string[] wheres;

		foreach(i, col; whereCondition) 
		{
			wheres ~= "`" ~i~ "`=" ~"'" ~ escape(col) ~ "'";
		}
		if(wheres.length != 0 )
		{
			sql.put(" WHERE ");
			sql.put(wheres.join(" AND "));
		}
		if(limit > 0)
		{
			sql.put(" LIMIT ");

			sql.put(to!string(limit));
		}
		return query(sql.data);
	}

	string escape(string str) {
		ubyte[] buffer = new ubyte[str.length * 2 + 1];
		buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, cast(uint) str.length);

		return cast(string) buffer;
	}

	string escaped(T...)(string sql, T t) {
		static if(t.length > 0) {
			string fixedup;
			int pos = 0;


			void escAndAdd(string str, int q) {
				ubyte[] buffer = new ubyte[str.length * 2 + 1];
				buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, str.length);

				fixedup ~= sql[pos..q] ~ '\'' ~ cast(string) buffer ~ '\'';

			}

			foreach(a; t) {
				int q = sql[pos..$].indexOf("?");
				if(q == -1)
					break;
				q += pos;

				static if(__traits(compiles, t is null)) {
					if(t is null)
						fixedup  ~= sql[pos..q] ~ "NULL";
					else
						escAndAdd(to!string(*a), q);
				} else {
					string str = to!string(a);
					escAndAdd(str, q);
				}

				pos = q+1;
			}

			fixedup ~= sql[pos..$];

			sql = fixedup;

			//writefln("\n\nExecuting sql: %s", sql);
		}

		return sql;
	}


	ResultByDataObject!R queryDataObject(R = DataObject, T...)(string sql, T t) {
		// modify sql for the best data object grabbing
		sql = fixupSqlForDataObjectUse(sql);
		//import std.stdio;
		//writeln(sql);
		auto magic = query(sql, t);
		//writeln("------------------------");
		return ResultByDataObject!R(cast(MySqlResult) magic, this);
	}


	ResultByDataObject!R queryDataObjectWithCustomKeys(R = DataObject, T...)(string[string] keyMapping, string sql, T t) {
		sql = fixupSqlForDataObjectUse(sql, keyMapping);

		auto magic = query(sql, t);
		return ResultByDataObject!R(cast(MySqlResult) magic, this);
	}

	int affectedRows() {
		return cast(int) mysql_affected_rows(mysql);
	}

	override ResultSet queryImpl(string sql, Variant[] args...) {
		import std.stdio;

		//writeln("query before....", sql);
		sql = escapedVariants(this, sql, args);
		//writeln("query after....",sql);

		/*enforceEx!(DatabaseException)(
		!mysql_query(mysql, toCstring(sql)),
		error() ~ " :::: " ~ sql);
		*/
		try{
			mysql_query(mysql, toCstring(sql));
		}
		catch(DatabaseException ex)
		{
			std.stdio.writeln( ex.msg, " :::: " , sql);
		}
		//writeln("query tocstring....",toCstring(sql));
		return new MySqlResult(mysql_store_result(mysql), sql);
	}

private:
	MYSQL* mysql;
}

struct ResultByDataObject(ObjType) if (is(ObjType : DataObject)) {
	this(MySqlResult r, MySql mysql) {
		import std.stdio;
		result = r;
		auto fields = r.fields();
		this.mysql = mysql;

		foreach(i, f; fields) {
			string tbl = fromCstring(f.org_table is null ? f.table : f.org_table, f.org_table is null ? f.table_length : f.org_table_length);
			mappings[fromCstring(f.name)] = tuple(
												  tbl,
												  fromCstring(f.org_name is null ? f.name : f.org_name, f.org_name is null ? f.name_length : f.org_name_length));
		}


	}

	Tuple!(string, string)[string] mappings;

	ulong length() { return result.length; }
	bool empty() { return result.empty; }
	void popFront() { result.popFront(); }
	ObjType front() {
		return new ObjType(mysql, result.front.toAA, mappings);
	}
	// would it be good to add a new() method? would be valid even if empty
	// it'd just fill in the ID's at random and allow you to do the rest

	@disable this(this) { }

	MySqlResult result;
	MySql mysql;
}

import std.string;
cstring toCstring(string c) {
	return cast(cstring) toStringz(c);
}

import std.array;
string fromCstring(cstring c, size_t len = size_t.max) {
	string ret;
	if(c is null)
		return null;
	if(len == 0)
		return "";
	if(len == size_t.max) {
		auto iterator = c;
		len =0;
		while(*iterator)
		{
			iterator++;

			// note they are both byte pointers, so this is sane
			//len = cast(int) iterator - cast(int) c;
			len++;
		}
		assert(len >= 0);
	}

	ret = cast(string) (c[0 .. len].idup);

	return ret;
}


// FIXME: this should work generically with all database types and them moved to database.d
Ret queryOneRow(Ret = Row, DB, string file = __FILE__, size_t line = __LINE__, T...)(DB db, string sql, T t) if(
																												(is(DB : Database))
																												// && (is(Ret == Row) || is(Ret : DataObject)))
																												)
{
	static if(is(Ret : DataObject) && is(DB == MySql)) {
		auto res = db.queryDataObject!Ret(sql, t);
		if(res.empty)
			throw new EmptyResultException("result was empty", file, line);
		return res.front;
	} else static if(is(Ret == Row)) {
		auto res = db.query(sql, t);
		if(res.empty)
			throw new EmptyResultException("result was empty", file, line);
		return res.front;
	} else static assert(0, "Unsupported single row query return value, " ~ Ret.stringof);
}

class EmptyResultException : Exception {
	this(string message, string file = __FILE__, size_t line = __LINE__) {
		super(message, file, line);
	}
}


/*
void main() {
auto mysql = new MySql("localhost", "uname", "password", "test");
scope(exit) delete mysql;


foreach(row; mysql.query("SELECT * FROM users")) {
writefln("%s %s %s %s", row["id"], row[0], row[1], row["username"]);
}
}
*/

/*
struct ResultByStruct(T) {
this(MySql.Result* r) {
result = r;
fields = r.fieldNames();
}

ulong length() { return result.length; }
bool empty() { return result.empty; }
void popFront() { result.popFront(); }
T front() {
auto r = result.front;
T ret;
foreach(i, a; r) {
ret[fields[i]] = a;
}

return ret;
}

@disable this(this) { }

string[] fields;
MySql.Result* result;
}
*/


/+
mysql.linq.tablename.field[key] // select field from tablename where id = key

mysql.link["name"].table.field[key] // select field from table where name = key


auto q = mysql.prepQuery("select id from table where something");
q.sort("name");
q.limit(start, count);
q.page(3, pagelength = ?);

q.execute(params here); // returns the same Result range as query
+/

/*
void main() {
auto db = new MySql("localhost", "uname", "password", "test");
foreach(item; db.queryDataObject("SELECT users.*, username
FROM users, password_manager_accounts
WHERE password_manager_accounts.user_id =  users.id LIMIT 5")) {
writefln("item: %s, %s", item.id, item.username);
item.first = "new";
item.last = "new2";
item.username = "kill";
//item.commitChanges();
}
}
*/


/*
Copyright: Adam D. Ruppe, 2009 - 2011
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors: Adam D. Ruppe, with contributions from Nick Sabalausky

Copyright Adam D. Ruppe 2009 - 2011.
Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at
http://www.boost.org/LICENSE_1_0.txt)
*/

///The MySQL server has gone away.
enum CR_SERVER_GONE_ERROR = 2006;
///The connection to the server was lost during the query.
enum CR_SERVER_LOST = 2013;



extern(System) {
	struct MYSQL;
	struct MYSQL_RES;
	/* typedef */ alias const(ubyte)* cstring;

	struct MYSQL_FIELD {
		cstring name;                 /* Name of column */
		cstring org_name;             /* Original column name, if an alias */ 
		cstring table;                /* Table of column if column was a field */
		cstring org_table;            /* Org table name, if table was an alias */
		cstring db;                   /* Database for table */
		cstring catalog;	      /* Catalog for table */
		cstring def;                  /* Default value (set by mysql_list_fields) */
		c_ulong length;       /* Width of column (create length) */
		c_ulong max_length;   /* Max width for selected set */
		uint name_length;
		uint org_name_length;
		uint table_length;
		uint org_table_length;
		uint db_length;
		uint catalog_length;
		uint def_length;
		uint flags;         /* Div flags */
		uint decimals;      /* Number of decimals in field */
		uint charsetnr;     /* Character set */
		uint type; /* Type of field. See mysql_com.h for types */
		// type is actually an enum btw

		version(MySQL_51) {
			void* extension;
		}
	}

	enum mysql_option   
	{  
		MYSQL_OPT_CONNECT_TIMEOUT, MYSQL_OPT_COMPRESS, MYSQL_OPT_NAMED_PIPE,  
		MYSQL_INIT_COMMAND, MYSQL_READ_DEFAULT_FILE, MYSQL_READ_DEFAULT_GROUP,  
		MYSQL_SET_CHARSET_DIR, MYSQL_SET_CHARSET_NAME, MYSQL_OPT_LOCAL_INFILE,  
		MYSQL_OPT_PROTOCOL, MYSQL_SHARED_MEMORY_BASE_NAME, MYSQL_OPT_READ_TIMEOUT,  
		MYSQL_OPT_WRITE_TIMEOUT, MYSQL_OPT_USE_RESULT,  
		MYSQL_OPT_USE_REMOTE_CONNECTION, MYSQL_OPT_USE_EMBEDDED_CONNECTION,  
		MYSQL_OPT_GUESS_CONNECTION, MYSQL_SET_CLIENT_IP, MYSQL_SECURE_AUTH,  
		MYSQL_REPORT_DATA_TRUNCATION, MYSQL_OPT_RECONNECT  
	}; 

	/* typedef */ alias cstring* MYSQL_ROW;

	cstring mysql_get_client_info();
	MYSQL* mysql_init(MYSQL*);
	uint mysql_errno(MYSQL*);
	cstring mysql_error(MYSQL*);

	MYSQL* mysql_real_connect(MYSQL*, cstring, cstring, cstring, cstring, uint, cstring, c_ulong);

	int mysql_options(MYSQL *mysql, mysql_option option, const void *arg);

	int mysql_query(MYSQL*, cstring);
	int mysql_ping(MYSQL*);


	void mysql_close(MYSQL*);

	ulong mysql_num_rows(MYSQL_RES*);
	uint mysql_num_fields(MYSQL_RES*);
	bool mysql_eof(MYSQL_RES*);

	ulong mysql_affected_rows(MYSQL*);
	ulong mysql_insert_id(MYSQL*);

	MYSQL_RES* mysql_store_result(MYSQL*);
	MYSQL_RES* mysql_use_result(MYSQL*);

	MYSQL_ROW mysql_fetch_row(MYSQL_RES *);
	c_ulong* mysql_fetch_lengths(MYSQL_RES*);
	MYSQL_FIELD* mysql_fetch_field(MYSQL_RES*);
	MYSQL_FIELD* mysql_fetch_fields(MYSQL_RES*);

	uint mysql_real_escape_string(MYSQL*, ubyte* to, cstring from, c_ulong length);

	void mysql_free_result(MYSQL_RES*);
	size_t mysql_thread_id(MYSQL* mysql);

}
