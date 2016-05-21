import std.stdio;
import std.database.mysql;
import std.database.util;
import std.adapter.adapter;

void main()
{
    auto test = new database("mysql","127.0.0.1",3306,"root","123456","cc");
    test.connection();
    writeln("start............");
    auto db = createDatabase("mysql://127.0.0.1:3306/cc?username=root&password=123456");
    auto con = db.connection();
    auto stmt = con.statement("select * from users"); 
    auto rows = stmt.query.rows;
    foreach(r;rows) 
    {
        writeln(r[0].as!int,",",r[1].as!string);
    }
}
