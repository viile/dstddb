module std.adapter.adapter;

import std.stdio;
import std.string;
import std.database.mysql;

interface adapter
{
}

class database : adapter
{
	public {
		string dbtype;
		string host;
		int port;
		string username;
		string password;
		string dbname;
		database db;
		ResultSet result;
	}

	this(string dbtype,string host,int port,string username,string password,string dbname)
	{
		this.dbtype = dbtype;
		this.host = host;
		this.port = port;
		this.username = username;
		this.password = password;
		this.dbname = dbname;
	}

	database connection()
	{
		return db;
	}

	void close()
	{
	
	}

	ResultSet query()
	{
		return result;
	}
}

interface result
{

}

class ResultSet : result
{

}
