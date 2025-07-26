const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'chatapp.db');
const db = new sqlite3.Database(dbPath);

console.log('📊 Chat App Database Inspector');
console.log('===============================\n');

// Function to display table contents
function displayTable(tableName, callback) {
  console.log(`🗂️  ${tableName.toUpperCase()} TABLE:`);
  console.log('-'.repeat(50));
  
  db.all(`SELECT * FROM ${tableName}`, (err, rows) => {
    if (err) {
      console.error(`Error reading ${tableName}:`, err.message);
    } else if (rows.length === 0) {
      console.log('No data found.');
    } else {
      console.table(rows);
    }
    console.log('');
    if (callback) callback();
  });
}

// Display all tables
displayTable('users', () => {
  displayTable('chats', () => {
    displayTable('chat_participants', () => {
      displayTable('messages', () => {
        // Close database connection
        db.close((err) => {
          if (err) {
            console.error('Error closing database:', err.message);
          } else {
            console.log('✅ Database inspection completed.');
          }
        });
      });
    });
  });
});
