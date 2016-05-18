import std.stdio;
import std.database.mysql;

void main()
{
    auto db = createDatabase("mysql://127.0.0.1/test");
    auto con = db.connection();
    auto stmt = con.statement("select * from table");
    auto rows = stmt.query.rows;
}
