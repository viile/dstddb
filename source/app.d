import std.stdio;
import std.database.mysql;
import std.database.util;

void main()
{
    /*
    auto db = createDatabase("file:///demo");
    auto rows = db.connection.query("select * from user").rows;
    foreach(r;rows) 
    {
        writeln(r[0].as!int,",",r[1].as!string);
    }
    */
    auto db = createDatabase("mysql://127.0.0.1:3306/cc?username=root&password=123456");
    auto con = db.connection();
    con.statement("select * from users").writeRows;
    /*
    auto stmt = con.statement("select * from users");
    auto rows = stmt.query.rows;
    foreach(r;rows)
    {
        writeln(r[0].as!string,",",r[1].as!string,",".r[2].as!string);
    }
    */
}
