module db.factory;

import db.database;
import utils.ini;

version(USE_MYSQL)
{
	import db.driver.mysql;
}
else version(USE_PGSQL)
{
	import db.driver.postgres;
}
else version(USE_Sqlite3)
{
	import db.driver.sqlite;
}


/*
void run(string v)
{
import std.stdio;
int n=0;
while(true)
{
//auto set = db.query("select id, name from user");
foreach(row; db.query("select * from user")) {
writefln("%s: %s %s %s %s",n++, row["id"], row[0], row[1], row["name"]);
}
}
}
*/
/**
* 数据库操作
*/
struct DbFactory{

	private{
		version(USE_MYSQL)
		{
			import db.driver.mysql;
			static MySql _connection;
		}
		else version(USE_PGSQL)
		{
			import db.driver.postgres;
			static PostgreSql _connection;
		}
		else version(USE_Sqlite3)
		{
			import db.driver.sqlite;
			static Sqlite _connection;
		}
	}
	/**
	* Test if a connection is active
	*
	* @return boolean
	*/
    public bool isConnected()
    {
		if(this._connection is null)
		{
			return false;
		}
		
		auto beforeid = this._connection.getThreadId();

		if(0 == this._connection.pingMysql())
		{
			///reconnect
			if(beforeid != this._connection.getThreadId())
			{
				auto charset = Ini.getInstance().value("mysql", "charset");
				this._connection.query(std.string.format("SET NAMES '%s'", charset));
			}
			return true;
		}
		else
		{
			return false;
		}
    }

	/**
	* Force the connection to close.
	*
	* @return void
	*/
    public void closeConnection()
    {
        if (isConnected()) {
            this._connection.close();
        }
        this._connection = null;
    }

	/**
	* Creates a connection to the database.
	*
	* @return void
	* @throws 
	*/
    protected void _connect()
    {
        if (this.isConnected()) {
            return;
        }

		version(USE_MYSQL)
		{
			auto host = Ini.getInstance().value("mysql", "host");
			auto username = Ini.getInstance().value("mysql", "username");
			auto password = Ini.getInstance().value("mysql", "password");
			auto dbname = Ini.getInstance().value("mysql", "dbname");
			auto charset = Ini.getInstance().value("mysql", "charset");
			uint port = std.conv.to!uint(Ini.getInstance().value("mysql", "port"));
			debug(info){
				import std.stdio;
				writeln(host,"----",username,"----",port,"----",password,"----",dbname,"----",charset);
			}
			this._connection = new MySql(host, username, password, dbname, port);

			//set names
			this._connection.query(std.string.format("SET NAMES '%s'", charset));
		}
		else version(USE_PGSQL)
		{

		}
		else version(USE_Sqlite3)
		{
		}
    }
	version(USE_MYSQL)
	{
		/**
		* Returns the underlying database connection object or resource.
		* If not presently connected, this initiates the connection.
		*
		* @return object|resource|null
		*/
		public MySql getConnection()
		{
			this._connect();
			return this._connection;
		}
	}
	else version(USE_PGSQL)
	{
		/**
		* Returns the underlying database connection object or resource.
		* If not presently connected, this initiates the connection.
		*
		* @return object|resource|null
		*/
		public PostgreSql getConnection()
		{
			this._connect();
			return this._connection;
		}
	}
	else version(USE_Sqlite3)
	{
		/**
		* Returns the underlying database connection object or resource.
		* If not presently connected, this initiates the connection.
		*
		* @return object|resource|null
		*/
		public Sqlite getConnection()
		{
			this._connect();
			return this._connection;
		}
	}
	

}
