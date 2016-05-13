
module dart.query;

import std.array;
import std.conv;
import std.format;
import std.variant;

interface QueryBuilder {

    /**
     * Gets the list of query parameters.
     **/
    Variant[] getParameters();

    /**
     * Converts the current builder state into a query string.
     **/
    string build();

}

/**
 * Exception type produced by query operations.
 **/
class QueryException : Exception {

    /**
     * Constructs a query exception with an error message.
     **/
    this(string message) {
        super(message);
    }

}

/**
 * Query builder, for generic and prebaked queries from strings.
 **/
class GenericQuery : QueryBuilder {

    private {

        string query;
        Variant[] params;

    }

    /**
     * Constructs a generic query from a query string and parameters.
     **/
    this(string query, Variant[] params = null...)
    in {
        if(query is null) {
            throw new QueryException("Query string cannot be null.");
        }
    } body {
        this.query = query;
        this.params = params;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        return query;
    }

}

/**
 * Builder for query where-clauses.
 **/
class WhereBuilder : QueryBuilder {

    private {

        Appender!string query;

        Variant[] params;

    }

    /**
     * Constructs an empty where-clause builder.
     **/
    this() {
        query = appender!string;
    }

    /**
     * Constructs a where-clause builder from a query string
     * and optionally a set of parameters.
     **/
    this(string query, Variant[] params = null...)
    in {
        if(query is null) {
            throw new QueryException("Query string cannot be null.");
        }
    } body {
        this.query = appender!string;
        this.query.put(query);
        this.params = params;
    }

    /**
     * Inserts an 'AND' operator.
     **/
    WhereBuilder and() {
        query.put(" AND ");
        return this;
    }

    /**
     * Inserts a 'XOR' (exclusive or) operator.
     **/
    WhereBuilder xor() {
        query.put(" XOR ");
        return this;
    }

    /**
     * Inserts an 'OR' operator.
     **/
    WhereBuilder or() {
        query.put(" OR ");
        return this;
    }

    /**
     * Opens a set of parentheses.
     **/
    WhereBuilder openParen() {
        query.put("(");
        return this;
    }

    /**
     * Closes a set of parentheses.
     **/
    WhereBuilder closeParen() {
        query.put(")");
        return this;
    }

    /**
     * Performs a comparison between the column and a value,
     * using the specified operator.
     **/
    WhereBuilder compare(VT)(string column, string operator, VT value)
    in {
        if(column is null || operator is null) {
            throw new QueryException("Column name and operator cannot be null.");
        }
    } body {
        // Append the query segment.
		//if(VT==Variant)
		//{
		//    std.stdio.writeln(value.type);
		//}
		//else
		//{
		//    std.stdio.writeln(typeid(value));
		//}
		
		static if(is(VT == Variant)) 
		{
           
			if(value.type ==typeid(string))
			{
				formattedWrite(query, "`%s` %s %s", column, operator, "'"~std.conv.to!string(value)~"'");
			}
			else
			{
				formattedWrite(query, "`%s` %s %s", column, operator, value);
			}
			
        } else 
		{
            if(typeid(value) ==typeid(string))
			{
				formattedWrite(query, "`%s` %s %s", column, operator, "'"~std.conv.to!string(value)~"'");
			}
			else
			{
				formattedWrite(query, "`%s` %s %s", column, operator, value);
			}
        }

        // Convert value to variant.
        static if(is(VT == Variant)) {
            params ~= value;
        } else {
            params ~= Variant(value);
        }

        return this;
    }

    /**
     * Performs an 'IS NULL' check on the specified column.
     **/
    WhereBuilder isNull(string column)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        // Append the query segment.
        formattedWrite(query, "`%s` IS NULL", column);

        return this;
    }

    /**
     * Performs an 'IS NOT NULL' check on the specified column.
     **/
    WhereBuilder isNotNull(string column)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        // Append the query segment.
        formattedWrite(query, "`%s` IS NOT NULL", column);

        return this;
    }

    /**
     * Tests if a column is equal to the value.
     **/
    WhereBuilder equals(VT)(string column, VT value) {
        return compare(column, "=", value);
    }
    /**
     * Tests if a column is not equal to the value.
     **/
    WhereBuilder notEquals(VT)(string column, VT value) {
        return compare(column, "!=", value);
    }

    /**
     * Tests if a column is 'LIKE' the value.
     **/
    WhereBuilder like(VT)(string column, VT value) {
        return compare(column, "LIKE", value);
    }

    /**
     * Tests if a column is 'NOT LIKE' the value.
     **/
    WhereBuilder notLike(VT)(string column, VT value) {
        return compare(column, "NOT LIKE", value);
    }

    /**
     * Tests if a column is less than the value.
     **/
    WhereBuilder lessThan(VT)(string column, VT value) {
        return compare(column, "<", value);
    }

    /**
     * Tests if a column is greater than the value.
     **/
    WhereBuilder greaterThan(VT)(string column, VT value) {
        return compare(column, ">", value);
    }

    /**
     * Tests if a column is less than or equal to the value.
     **/
    WhereBuilder lessOrEqual(VT)(string column, VT value) {
        return compare(column, "<=", value);
    }

    /**
     * Tests if a column is greater than or equal to the value.
     **/
    WhereBuilder greaterOrEqual(VT)(string column, VT value) {
        return compare(column, ">=", value);
    }

    /**
     * Tests if the column appears in a set of values.
     **/
    WhereBuilder whereIn(VT)(string column, VT[] values...)
    in {
        if(column is null || values is null) {
            throw new QueryException("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` IN (");
        foreach(int idx, value; values) {
            query.put("?");
            if(idx < values.length - 1) {
                query.put(", ");
            }

            // Convert value to variant.
            static if(is(VT == Variant)) {
                params ~= value;
            } else {
                params ~= Variant(value);
            }
        }
        query.put(")");

        return this;
    }

    /**
     * Tests if the column appears in a set of values produced by a query.
     **/
    WhereBuilder whereIn(string column, SelectBuilder select)
    in {
        if(column is null || select is null) {
            throw new QueryException("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` IN (");
        query.put(select.build ~ ")");

        params = join([params, select.getParameters]);
        return this;
    }

    /**
     * Tests if the column does not appear in a set of values.
     **/
    WhereBuilder whereNotIn(VT)(string column, VT[] values...)
    in {
        if(column is null || values is null) {
            throw new QueryException("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` NOT IN (");
        foreach(int idx, value; values) {
            query.put("?");
            if(idx < values.length - 1) {
                query.put(", ");
            }

            // Convert value to variant.
            static if(is(VT == Variant)) {
                params ~= value;
            } else {
                params ~= Variant(value);
            }
        }
        query.put(")");

        return this;
    }

    /**
     * Tests if the column does not appear in a set of values produced by a query.
     **/
    WhereBuilder whereNotIn(string column, SelectBuilder select)
    in {
        if(column is null || select is null) {
            throw new QueryException("Column name and values cannot be null.");
        }
    } body {
        // Build the where-in clause.
        query.put("`" ~ column ~ "` NOT IN (");
        query.put(select.build ~ ")");

        params = join([params, select.getParameters]);
        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        return query.data;
    }

}

/**
 * Query builder component for from-clause.
 **/
mixin template FromFunctions(T : QueryBuilder) {

    private {

        string fromTable;

        SelectBuilder fromQuery;
        string fromAsName;

    }

    /**
     * Specifies a from value as a table name.
     **/
    T from(string table)
    in {
        if(table is null) {
            throw new QueryException("Table cannot be null.");
        }
    } body {
        fromTable = table;
        return this;
    }

    /**
     * Specifies a from value as a subquery and assignment.
     **/
    T from(SelectBuilder query, string asName)
    in {
        if(query is null || asName is null) {
            throw new QueryException("Query and name cannot be null.");
        }
    } body {
        fromQuery = query;
        fromAsName = asName;
        return this;
    }

    protected {

        /**
         * Checks if from information has been specified.
         **/
        bool hasFrom() {
            return fromQuery !is null ||
                    fromTable !is null;
        }

        /**
         * Converts the from state into a query segment.
         **/
        string getFromSegment() {
            auto query = appender!string;

            // Check if we're using a query.
            if(fromQuery !is null) {
                formattedWrite(query, "%s AS %s",
                        fromQuery.build, fromAsName);
            } else {
                formattedWrite(query, "`%s`", fromTable);
            }

            return query.data;
        }

    }

}

/**
 * Query builder component for where-clause.
 **/
mixin template WhereFunctions(T : QueryBuilder) {

    private {

        string whereCondition;

    }

    /**
     * Sets the select condition from a string.
     **/
    T where(VT)(string where, VT[] params...)
    in {
        if(where is null) {
            throw new QueryException("Condition cannot be null.");
        }
    } body {
        // Assign query.
        whereCondition = where;

        // Query parameters.
        if(params !is null && params.length > 0) {
            static if(is(VT == Variant)) {
                this.params = join([this.params, params]);
            } else {
                // Convert params to variant array.
                foreach(param; params) {
                    this.params ~= Variant(param);
                }
            }
        }
		std.stdio.writeln("where: ", whereCondition, "param: ", params);
        return this;
    }

    /**
     * Sets the select condition from a where condition builder.
     **/
    T where(WhereBuilder where)
    in {
        if(where is null) {
            throw new QueryException("Condition cannot be null.");
        }
    } body {
        // Store query information.
        whereCondition = where.build();
        params = join([params, where.getParameters]);

        return this;
    }

    protected {

        /**
         * Checks if a where condition has been specified.
         **/
        bool hasWhere() {
            return whereCondition !is null;
        }

        /**
         * Converts the where state into a query segment.
         **/
        string getWhereSegment() {
            return whereCondition;
        }

    }

}

/**
 * Query builder component for order-by-clause.
 **/
mixin template OrderByFunctions(T : QueryBuilder) {

    /**
     * A type spcifying an order-by column and direction.
     **/
    struct OrderByInfo {

        string column;
        string direction;

        string toString() {
            auto query = appender!string;
            query.put(column);
            if(direction !is null) {
                query.put(" " ~ direction);
            }

            return query.data;
        }

    }

    private {

        OrderByInfo[] orderByColumns;

    }

    /**
     * Adds an order-by clause from a column name or expression
     * and optionally a direction (ASC, DESC, etc.)
     **/
    T orderBy(string column, string direction = null)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        // Save the Order-By specifier.
        orderByColumns ~= OrderByInfo(column, direction);

        return this;
    }

    /**
     * Adds a number of order-by clause from a list of
     * column names or expressions.
     **/
    T orderBy(string[] columns...)
    in {
        if(columns is null) {
            throw new QueryException("Columns list cannot be null.");
        }
    } body {
        // Add the columns to the list.
        foreach(column; columns) {
            orderByColumns ~= OrderByInfo(column);
        }

        return this;
    }

    /**
     * Adds a number of order-by clause from a list of
     * Order-By info structs.
     **/
    T orderBy(OrderByInfo[] columns...)
    in {
        if(columns is null) {
            throw new QueryException("Columns list cannot be null.");
        }
    } body {
        // Append the list of specifiers.
        orderByColumns = join([orderByColumns, columns]);

        return this;
    }

    protected {

        /**
         * Checks if order-by information has been specified.
         **/
        bool hasOrderBy() {
            return orderByColumns !is null &&
                    !orderByColumns.empty;
        }

        /**
         * Converts the order-by state into a query segment.
         **/
        string getOrderBySegment() {
            auto query = appender!string;
            formattedWrite(query, "%-(%s%|, %)",
                    orderByColumns);
            return query.data;
        }

    }

}

/**
 * Query builder component for limit-clause.
 **/
mixin template LimitFunctions(T : QueryBuilder) {

    private {

        int count = -1;

    }

    /**
     * Sets the operation limit for the query.
     **/
    T limit(int count)
    in {
        if(count < -1) {
            throw new QueryException("Limit cannot be negative.");
        }
    } body {
        this.count = count;
        return this;
    }

    protected {

        /**
         * Checks if a limit has been specified.
         **/
        bool hasLimit() {
            return count != -1;
        }

        /**
         * Converts the limit state into a query segment.
         **/
        string getLimitSegment() {
            return to!string(count);
        }

    }

}

class SelectBuilder : QueryBuilder {

    /**
     * Represents a select function call.
     **/
    struct SelectFunction {

        string name;
        string[] params;

        /**
         * Checks if the select function has a value.
         **/
        bool hasValue() {
            return name !is null;
        }

        string toString() {
            auto query = appender!string;
            formattedWrite(query, "%s(%-(%s%|, %))",
                    name, params);
            return query.data;
        }

    }

    /**
     * Stores a column list for a select operation.
     **/
    struct SelectColumns {

        string[] columns;

        /**
         * Checks if the select-columns list has a value.
         **/
        bool hasValue() {
            return columns !is null &&
                    !columns.empty;
        }

        string toString() {
            auto query = appender!string;
            formattedWrite(query, "%-(`%s`%|, %)", columns);
            return query.data;
        }

    }

    /**
     * Stores a list of tables and a condition for a join operation.
     **/
    struct SelectJoin {

        string[] joinTables;
        string joinOn;

        /**
         * Checks if the select-join has a value.
         **/
        bool hasValue() {
            return joinTables !is null &&
                    !joinTables.empty;
        }

        string toString() {
            auto query = appender!string;
            formattedWrite(query, "(%-(`%s`%|, %))", joinTables);
            if(joinOn !is null)
                formattedWrite(query, " ON %s", joinOn);
            return query.data;
        }

    }

    /**
     * Stores a secondary query for a union operation.
     **/
    struct SelectUnion {

        QueryBuilder subquery;
        bool distinct;

        /**
         * Checks if the select union has a value.
         **/
        bool hasValue() {
            return subquery !is null;
        }

        string toString() {
            auto query = appender!string;
            query.put(distinct ? " DISTINCT " : " ALL ");
            query.put(subquery.build);
            return query.data;
        }

    }

    private {

        SelectFunction selectFunction;
        SelectColumns selectColumns;

        SelectJoin selectJoin;
        SelectUnion selectUnion;

        bool selectForUpdate;

        Variant[] params;

    }

    /**
     * From component.
     **/
    mixin FromFunctions!(SelectBuilder);
    /**
     * Where component.
     **/
    mixin WhereFunctions!(SelectBuilder);
    /**
     * Order-By component.
     **/
    mixin OrderByFunctions!(SelectBuilder);
    /**
     * Limit component.
     **/
    mixin LimitFunctions!(SelectBuilder);

    /**
     * Creates a select query for the last insert id.
     **/
    static
    SelectBuilder lastInsertId() {
        return new SelectBuilder().selectFunc("LAST_INSERT_ID");
    }

    /**
     * Prepares a select query with a function and parameters.
     **/
    SelectBuilder selectFunc(string name, string[] params = null...)
    in {
        if(name is null) {
            throw new QueryException("Function name cannot be null.");
        }
    } body {
        selectFunction = SelectFunction(name, params);
        return this;
    }

    /**
     * Prepares a select query for the average of a column.
     **/
    SelectBuilder selectAvg(string column)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        return selectFunc("AVG", column);
    }

    /**
     * Prepares a select query for the max value of a column.
     **/
    SelectBuilder selectMax(string column)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        return selectFunc("MAX", column);
    }

    /**
     * Prepares a select query for the min value of a column.
     **/
    SelectBuilder selectMin(string column)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        return selectFunc("MIN", column);
    }

    /**
     * Prepares a select query for the sum of a column.
     **/
    SelectBuilder selectSum(string column)
    in {
        if(column is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        return selectFunc("SUM", column);
    }

    /**
     * Sets the list of column to select.
     **/
    SelectBuilder select(string[] columns...)
    in {
        // Check that the columns list isn't null.
        if(columns is null) {
            throw new QueryException("Columns list cannot be null.");
        }
    } body {
        selectColumns = SelectColumns(columns);
        return this;
    }

    /**
     * Performs a left-join operation on a list of tables,
     * with an optional join condition.
     **/
    SelectBuilder leftJoin(string[] tables, WhereBuilder condition = null)
    in {
        if(tables is null) {
            throw new QueryException("Tables list cannot be null.");
        }
    } body {
        if(condition is null) {
            selectJoin = SelectJoin(tables);
        } else {
            selectJoin = SelectJoin(tables, condition.build);
            params = join([params, condition.getParameters]);
        }

        return this;
    }

    /**
     * Performs a left-join operation on a list of tables.
     **/
    SelectBuilder leftJoin(string[] tables, string condition,
            Variant[] params = null...)
    in {
        if(tables is null) {
            throw new QueryException("Tables list cannot be null.");
        }
    } body {
        selectJoin = SelectJoin(tables, condition);
        this.params = join([this.params, params]);

        return this;
    }

    /**
     * Attaches an addition query to this one, through a union.
     **/
    SelectBuilder withUnion(QueryBuilder query, bool distinct = true)
    in {
        if(query is null) {
            throw new QueryException("Query cannot by null.");
        }
    } body {
        selectUnion = SelectUnion(query, distinct);
        return this;
    }

    SelectBuilder forUpdate() {
        selectForUpdate = true;
        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Select.
        query.put("SELECT ");
        if(selectFunction.hasValue) {
            // Select function.
            query.put(selectFunction.toString);
        } else if(selectColumns.hasValue) {
            // Select specific columns.
            query.put(selectColumns.toString);
        } else {
            // Select everything.
            query.put("*");
        }

        // From.
        if(hasFrom) {
            query.put(" FROM ");
            query.put(getFromSegment);
        }

        // Where.
        if(hasWhere) {
            query.put(" WHERE ");
            query.put(getWhereSegment);
        }

        // Order-By.
        if(hasOrderBy) {
            query.put(" ORDER BY ");
            query.put(getOrderBySegment);
        }

        // Limit.
        if(hasLimit) {
            query.put(" LIMIT ");
            query.put(getLimitSegment);
        }

        // For Update.
        if(selectForUpdate) {
            query.put(" FOR UPDATE");
        }

        // Join.
        if(selectJoin.hasValue) {
            query.put(" LEFT JOIN ");
            query.put(selectJoin.toString);
        }

        // Union.
        if(selectUnion.hasValue) {
            query.put(" UNION ");
            query.put(selectUnion.toString);
        }

		std.stdio.writeln(query.data);
        return query.data;
    }

}

class InsertBuilder : QueryBuilder {

    private {

        string table;
        string[] columns;

        Variant[] params;

    }

    /**
     * Sets the column list for this insert query.
     **/
    InsertBuilder insert(string[] columns...) {
        this.columns = columns;
        return this;
    }

    /**
     * Sets the 'INTO' clause in the query.
     **/
    InsertBuilder into(string table)
    in {
        if(table is null) {
            throw new QueryException("Table cannot be null.");
        }
    } body {
        this.table = table;
        return this;
    }

    /**
     * Appends a singe value to the query.
     *
     * Parameters are passed through a prepared statement,
     * and never appear in the query string itself.
     **/
    InsertBuilder value(VT)(VT value) {
        static if(is(VT == Variant)) {
            params ~= value;
        } else {
            // Convert value to variant array.
            params ~= Variant(value);
        }
		//std.stdio.writeln(params);
        return this;
    }

    /**
     * Appends a number of values to the query.
     *
     * Parameters are passed through a prepared statement,
     * and never appear in the query string itself.
     **/
    InsertBuilder values(VT)(VT[] values...)
    in {
        if(values is null) {
            throw new QueryException("Values cannot be null.");
        }
    } body {
        // Query parameters.
        static if(is(VT == Variant)) {
            params = join([params, values]);
        } else {
            // Convert values to variant array.
            foreach(param; params) {
                params ~= Variant(values);
            }
        }

        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Insert into.
        query.put("INSERT INTO ");
        query.put(table);

        // (Columns).
        if(columns !is null) {
            // Insert into specific columns.
            formattedWrite(query, "(%-(`%s`%|, %))", columns);
        }

        // Values.
        query.put(" VALUES (");
        foreach(index, param; params) {
			//std.stdio.writeln(param.toString(), " ", param.type, " ", typeid(string));
			if(param.type == typeid(string) || param.type == typeid(dstring)|| param.type == typeid(wstring))
			{
				query.put("'"~param.toString()~"'");
			}
			else
			{
				query.put(param.toString());
			}
            if(index < params.length - 1) {
                query.put(", ");
            }
        }

        query.put(");");
		std.stdio.writeln(query);
        return query.data;
    }

}

class DeleteBuilder : QueryBuilder {

    private {

        string table;

        Variant[] params;

    }

    /**
     * From component.
     **/
    mixin FromFunctions!(DeleteBuilder);
    /**
     * Where component.
     **/
    mixin WhereFunctions!(DeleteBuilder);
    /**
     * Order-By component.
     **/
    mixin OrderByFunctions!(DeleteBuilder);
    /**
     * Limit component.
     **/
    mixin LimitFunctions!(DeleteBuilder);

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Delete.
        query.put("DELETE ");

        // From.
        if(hasFrom) {
            query.put(" FROM ");
            query.put(getFromSegment);
        }

        // Where.
        if(hasWhere) {
            query.put(" WHERE ");
            query.put(getWhereSegment);
        }

        // Order-By.
        if(hasOrderBy) {
            query.put(" ORDER BY ");
            query.put(getOrderBySegment);
        }

        // Limit.
        if(hasLimit) {
            query.put(" LIMIT ");
            query.put(getLimitSegment);
        }

        query.put(";");
        return query.data;
    }

}

class UpdateBuilder : QueryBuilder {

    private {

        string table;
        string[] columns;

        Variant[] params;

    }

    /**
     * Where component.
     **/
    mixin WhereFunctions!(UpdateBuilder);
    /**
     * Order-By component.
     **/
    mixin OrderByFunctions!(UpdateBuilder);
    /**
     * Limit component.
     **/
    mixin LimitFunctions!(UpdateBuilder);

    /**
     * Sets the table the update query targets.
     **/
    UpdateBuilder update(string table)
    in {
        if(table is null) {
            throw new QueryException("Table cannot be null.");
        }
    } body {
        this.table = table;
        return this;
    }

    /**
     * Adds a column value to the update query.
     **/
    UpdateBuilder set(VT)(string name, VT value)
    in {
        if(name is null) {
            throw new QueryException("Column name cannot be null.");
        }
    } body {
        columns ~= name;
        params ~= value;
        return this;
    }

    /**
     * Adds multiple column values to the update query.
     **/
    UpdateBuilder set(VT)(VT[string] values...)
    in {
        if(name is null) {
            throw new QueryException("Values cannot be null.");
        }
    } body {
        // Add the values.
        foreach(name, value; values) {
            columns ~= name;
            // Convert value to variant.
            static if(is(VT == Variant)) {
                params ~= value;
            } else {
                params ~= Variant(value);
            }
        }

        return this;
    }

    Variant[] getParameters() {
        return params;
    }

    string build() {
        auto query = appender!string;

        // Update.
        query.put("UPDATE ");
        query.put(table);

        query.put(" SET ");
		//std.stdio.writeln("query= ", query, "columns= ",columns);
        //formattedWrite(query, "%-(`%s`=?%|, %)", columns);

		
		for(int i=0; i<columns.length;i++)
		{
			string value;
			if(params[i].type == typeid(string) || params[i].type == typeid(dstring) || params[i].type == typeid(wstring))
			{
				value = "'"~params[i].toString()~"'";
			}
			else
			{
				value = params[i].toString();
			}
			if(i == columns.length-1)
				formattedWrite(query, "`%s`=%s ", columns[i],value);
			else
				formattedWrite(query, "`%s`=%s, ", columns[i],value);
			//std.stdio.writeln("columns[",i,"]= ", columns[i], "\n", "params[",i,"]= ", params[i]);
		}
		//foreach(index, param; params) {
		//    //std.stdio.writeln(param.toString(), " ", param.type, " ", typeid(string));
		//    if(param.type == typeid(string))
		//    {
		//        query.put("'"~param.toString()~"'");
		//    }
		//    else
		//    {
		//        query.put(param.toString());
		//    }
		//    if(index < params.length - 1) {
		//        query.put(", ");
		//    }
		//}


		//std.stdio.writeln("getWhereSegment ", getWhereSegment);
        // Where.
        if(hasWhere) {
            query.put(" WHERE ");
            query.put(getWhereSegment);
        }

        // Order-By.
        if(hasOrderBy) {
            query.put(" ORDER BY ");
            query.put(getOrderBySegment);
        }

        // Limit.
        if(hasLimit) {
            query.put(" LIMIT ");
            query.put(getLimitSegment);
        }

        query.put(";");
		//std.stdio.writeln(query.data);
        return query.data;
    }

}
