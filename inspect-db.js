const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbPath = path.join(__dirname, 'chatapp.db');
const db = new sqlite3.Database(dbPath);




function displayTable(tableName, callback) {
  console.log(`  ${tableName.toUpperCase()} TABLE:`);
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


displayTable('users', () => {
  displayTable('chats', () => {
    displayTable('chat_participants', () => {
      displayTable('messages', () => {
        displayTable('message_read_status', () => {
          
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
});
