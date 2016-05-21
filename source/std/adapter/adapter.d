module adapter.adapter;

import std.stdio;

interface adapter
{
}

class database : adapter
{
	database db;
	ResultSet result;
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
