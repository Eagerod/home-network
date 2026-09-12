const sqlite3 = require('@louislam/sqlite3').verbose();

function exportTable(db, tableName, callback) {
	let output = 'PRAGMA foreign_keys=OFF;\n';
	output += 'BEGIN TRANSACTION;\n';

	// Step 1: Get the schema of the table (CREATE TABLE statement)
	db.get(`SELECT sql FROM sqlite_master WHERE type='table' AND name=?`, [tableName], (err, row) => {
		if (err) {
			console.error(err);
			return;
		}

		if (row) {
			const createTableSql = row.sql.replace('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS');
			output += `${createTableSql};\n`;
		} else {
			console.error(`No record found for schema: ${tableName}`);
			return;
		}

		db.all(`SELECT * FROM \`${tableName}\``, [], (err, rows) => {
			if (err) {
				console.error(err);
				return;
			}

			rows.forEach(row => {
				//const columns = Object.keys(row).map(col => `"${col}"`).join(', ');
				const values = Object.values(row).map(val => {
					if (val === null) {
						return 'NULL';
					} else if (typeof val === 'string') {
						if (val.indexOf("\n") != -1) {
							return `replace('${val.replace(/'/g, "''").replace("\n", "\\n")}','\\n',char(10))`;  // Escape single quotes in strings
						}
						return `'${val.replace(/'/g, "''")}'`;
					} else {
						return val;
					}
				}).join(',');

				// sqlite3 binary dump wraps with quotes for keywords; could be expanded to support more.
				if (tableName == "group") {
					tableName = '"group"';
				}
				// output += `INSERT INTO ${tableName} (${columns}) VALUES (${values});\n`;
				output += `INSERT INTO ${tableName} VALUES(${values});\n`;
			});

			output += 'COMMIT;\n';
			callback(output);
		});
	});
}

// node <script> <source> <table>
if (process.argv.length != 4) {
	console.error("Usage:");
	console.error(`  ${process.argv[0]} ${process.argv[1]} <source/path> <tablename>`);
	process.exit(1);
}

const db = new sqlite3.Database(process.argv[2]);

exportTable(db, process.argv[3], (dump) => {
	console.log(dump);
});
