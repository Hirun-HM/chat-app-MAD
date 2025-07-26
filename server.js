const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Database setup
const dbPath = path.join(__dirname, 'chatapp.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
  } else {
    console.log('✅ Connected to SQLite database');
    initializeDatabase();
  }
});

// Initialize database tables
function initializeDatabase() {
  // Users table
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT UNIQUE,
      avatar TEXT,
      status TEXT DEFAULT 'offline',
      last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `, (err) => {
    if (err) {
      console.error('Error creating users table:', err.message);
    } else {
      console.log('✅ Users table ready');
    }
  });

  // Chats table (for individual and group chats)
  db.run(`
    CREATE TABLE IF NOT EXISTS chats (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      type TEXT NOT NULL CHECK(type IN ('individual', 'group')),
      icon TEXT,
      created_by INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (created_by) REFERENCES users (id)
    )
  `, (err) => {
    if (err) {
      console.error('Error creating chats table:', err.message);
    } else {
      console.log('✅ Chats table ready');
    }
  });

  // Chat participants table (many-to-many relationship)
  db.run(`
    CREATE TABLE IF NOT EXISTS chat_participants (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chat_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      is_admin BOOLEAN DEFAULT FALSE,
      FOREIGN KEY (chat_id) REFERENCES chats (id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
      UNIQUE(chat_id, user_id)
    )
  `, (err) => {
    if (err) {
      console.error('Error creating chat_participants table:', err.message);
    } else {
      console.log('✅ Chat participants table ready');
    }
  });

  // Messages table
  db.run(`
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      chat_id INTEGER NOT NULL,
      sender_id INTEGER NOT NULL,
      message_text TEXT,
      message_type TEXT DEFAULT 'text' CHECK(message_type IN ('text', 'image', 'video', 'audio', 'file')),
      file_path TEXT,
      reply_to INTEGER,
      sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      delivered_at DATETIME,
      read_at DATETIME,
      FOREIGN KEY (chat_id) REFERENCES chats (id) ON DELETE CASCADE,
      FOREIGN KEY (sender_id) REFERENCES users (id),
      FOREIGN KEY (reply_to) REFERENCES messages (id)
    )
  `, (err) => {
    if (err) {
      console.error('Error creating messages table:', err.message);
    } else {
      console.log('✅ Messages table ready');
      insertSampleData();
    }
  });
}

// Insert sample data for testing
function insertSampleData() {
  // Check if we already have sample users
  db.get("SELECT COUNT(*) as count FROM users", (err, row) => {
    if (err) {
      console.error('Error checking users:', err.message);
      return;
    }
    
    if (row.count === 0) {
      console.log('📝 Inserting sample data...');
      
      // Insert sample users
      const users = [
        { name: 'John Doe', phone: '+1234567890', avatar: 'person.svg' },
        { name: 'Jane Smith', phone: '+1234567891', avatar: 'person.svg' },
        { name: 'Mike Johnson', phone: '+1234567892', avatar: 'person.svg' },
        { name: 'Sarah Wilson', phone: '+1234567893', avatar: 'person.svg' }
      ];

      users.forEach((user, index) => {
        db.run(
          "INSERT INTO users (name, phone, avatar) VALUES (?, ?, ?)",
          [user.name, user.phone, user.avatar],
          function(err) {
            if (err) {
              console.error('Error inserting user:', err.message);
            } else {
              console.log(`✅ Inserted user: ${user.name} with ID: ${this.lastID}`);
              
              // After inserting all users, create some sample chats
              if (index === users.length - 1) {
                setTimeout(createSampleChats, 500);
              }
            }
          }
        );
      });
    }
  });
}

function createSampleChats() {
  // Create individual chats
  db.run(
    "INSERT INTO chats (name, type, created_by) VALUES (?, ?, ?)",
    ['Chat with Jane', 'individual', 1],
    function(err) {
      if (err) {
        console.error('Error creating chat:', err.message);
      } else {
        const chatId = this.lastID;
        // Add participants
        db.run("INSERT INTO chat_participants (chat_id, user_id) VALUES (?, ?)", [chatId, 1]);
        db.run("INSERT INTO chat_participants (chat_id, user_id) VALUES (?, ?)", [chatId, 2]);
        console.log(`✅ Created individual chat with ID: ${chatId}`);
      }
    }
  );

  // Create a group chat
  db.run(
    "INSERT INTO chats (name, type, created_by) VALUES (?, ?, ?)",
    ['University Group', 'group', 1],
    function(err) {
      if (err) {
        console.error('Error creating group chat:', err.message);
      } else {
        const chatId = this.lastID;
        // Add participants
        [1, 2, 3, 4].forEach(userId => {
          db.run("INSERT INTO chat_participants (chat_id, user_id, is_admin) VALUES (?, ?, ?)", 
            [chatId, userId, userId === 1]);
        });
        console.log(`✅ Created group chat with ID: ${chatId}`);
      }
    }
  );
}

// Store connected users and their socket IDs
const connectedUsers = new Map();

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`🔌 User connected: ${socket.id}`);

  // Handle user signin
  socket.on('signin', (userId) => {
    console.log(`👤 User ${userId} signed in with socket ${socket.id}`);
    connectedUsers.set(userId, socket.id);
    socket.userId = userId;
    
    // Update user status to online
    db.run("UPDATE users SET status = 'online' WHERE id = ?", [userId], (err) => {
      if (err) {
        console.error('Error updating user status:', err.message);
      }
    });

    // Join user to their chat rooms and send chat history
    getUserChats(userId, (chats) => {
      chats.forEach(chat => {
        socket.join(`chat_${chat.id}`);
        console.log(`📱 User ${userId} joined chat room: chat_${chat.id}`);
      });
    });
  });

  // Handle request for chat history
  socket.on('get_chat_history', (data) => {
    const { sourceId, targetId } = data;
    console.log(`📜 Getting chat history between ${sourceId} and ${targetId}`);
    
    findOrCreateChat(sourceId, targetId, (chatId) => {
      if (chatId) {
        // Get all messages for this chat
        db.all(
          `SELECT m.*, u.name as sender_name 
           FROM messages m
           JOIN users u ON m.sender_id = u.id
           WHERE m.chat_id = ?
           ORDER BY m.sent_at ASC`,
          [chatId],
          (err, messages) => {
            if (err) {
              console.error('Error getting chat history:', err.message);
            } else {
              console.log(`📤 Sending ${messages.length} messages to user ${sourceId}`);
              socket.emit('chat_history', {
                chatId: chatId,
                messages: messages.map(msg => ({
                  id: msg.id,
                  message: msg.message_text,
                  path: msg.file_path || '',
                  sender: msg.sender_name,
                  senderId: msg.sender_id,
                  sentAt: msg.sent_at,
                  type: msg.message_type,
                  // Determine if this message is from the current user
                  messageType: msg.sender_id === sourceId ? 'source' : 'destination'
                }))
              });
            }
          }
        );
      }
    });
  });

  // Handle sending messages
  socket.on('message', (data) => {
    console.log('📨 Received message:', data);
    
    const { message, sourceId, targetId, path } = data;
    
    // Find or create chat between source and target
    findOrCreateChat(sourceId, targetId, (chatId) => {
      if (chatId) {
        // Save message to database
        const messageType = path && path !== '' ? getMessageType(path) : 'text';
        
        db.run(
          `INSERT INTO messages (chat_id, sender_id, message_text, message_type, file_path, sent_at) 
           VALUES (?, ?, ?, ?, ?, datetime('now'))`,
          [chatId, sourceId, message, messageType, path],
          function(err) {
            if (err) {
              console.error('Error saving message:', err.message);
              return;
            }
            
            console.log(`✅ Message saved with ID: ${this.lastID}`);
            
            // Get the complete message data
            db.get(
              `SELECT m.*, u.name as sender_name 
               FROM messages m 
               JOIN users u ON m.sender_id = u.id 
               WHERE m.id = ?`,
              [this.lastID],
              (err, messageData) => {
                if (err) {
                  console.error('Error retrieving message:', err.message);
                  return;
                }
                
                // Broadcast message to all participants in the chat
                socket.to(`chat_${chatId}`).emit('message', {
                  id: messageData.id,
                  message: messageData.message_text,
                  path: messageData.file_path || '',
                  sender: messageData.sender_name,
                  senderId: messageData.sender_id,
                  sentAt: messageData.sent_at,
                  type: messageData.message_type
                });
                
                // Update chat's last message timestamp
                db.run(
                  "UPDATE chats SET updated_at = datetime('now') WHERE id = ?",
                  [chatId]
                );
              }
            );
          }
        );
      }
    });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log(`🔌 User disconnected: ${socket.id}`);
    
    if (socket.userId) {
      connectedUsers.delete(socket.userId);
      
      // Update user status to offline
      db.run(
        "UPDATE users SET status = 'offline', last_seen = datetime('now') WHERE id = ?",
        [socket.userId],
        (err) => {
          if (err) {
            console.error('Error updating user status:', err.message);
          }
        }
      );
    }
  });
});

// Helper functions
function getUserChats(userId, callback) {
  db.all(
    `SELECT DISTINCT c.* 
     FROM chats c
     JOIN chat_participants cp ON c.id = cp.chat_id
     WHERE cp.user_id = ?
     ORDER BY c.updated_at DESC`,
    [userId],
    (err, rows) => {
      if (err) {
        console.error('Error getting user chats:', err.message);
        callback([]);
      } else {
        callback(rows);
      }
    }
  );
}

function findOrCreateChat(sourceId, targetId, callback) {
  // First, try to find existing individual chat between these users
  db.get(
    `SELECT c.id 
     FROM chats c
     JOIN chat_participants cp1 ON c.id = cp1.chat_id
     JOIN chat_participants cp2 ON c.id = cp2.chat_id
     WHERE c.type = 'individual' 
     AND cp1.user_id = ? 
     AND cp2.user_id = ?
     AND c.id IN (
       SELECT chat_id 
       FROM chat_participants 
       GROUP BY chat_id 
       HAVING COUNT(*) = 2
     )`,
    [sourceId, targetId],
    (err, row) => {
      if (err) {
        console.error('Error finding chat:', err.message);
        callback(null);
      } else if (row) {
        // Chat exists
        callback(row.id);
      } else {
        // Create new chat
        db.run(
          "INSERT INTO chats (type, created_by) VALUES ('individual', ?)",
          [sourceId],
          function(err) {
            if (err) {
              console.error('Error creating chat:', err.message);
              callback(null);
            } else {
              const chatId = this.lastID;
              
              // Add both participants
              db.run("INSERT INTO chat_participants (chat_id, user_id) VALUES (?, ?)", [chatId, sourceId]);
              db.run("INSERT INTO chat_participants (chat_id, user_id) VALUES (?, ?)", [chatId, targetId]);
              
              console.log(`✅ Created new chat with ID: ${chatId}`);
              callback(chatId);
            }
          }
        );
      }
    }
  );
}

function getMessageType(filePath) {
  if (!filePath) return 'text';
  
  const extension = path.extname(filePath).toLowerCase();
  
  if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].includes(extension)) {
    return 'image';
  } else if (['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm'].includes(extension)) {
    return 'video';
  } else if (['.mp3', '.wav', '.aac', '.ogg', '.m4a'].includes(extension)) {
    return 'audio';
  } else {
    return 'file';
  }
}

// REST API endpoints
app.get('/api/users', (req, res) => {
  db.all("SELECT id, name, phone, avatar, status FROM users", (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
    } else {
      res.json(rows);
    }
  });
});

app.get('/api/chats/:userId', (req, res) => {
  const userId = req.params.userId;
  
  db.all(
    `SELECT DISTINCT c.id, c.name, c.type, c.icon, c.updated_at,
            (SELECT message_text FROM messages WHERE chat_id = c.id ORDER BY sent_at DESC LIMIT 1) as last_message,
            (SELECT sent_at FROM messages WHERE chat_id = c.id ORDER BY sent_at DESC LIMIT 1) as last_message_time
     FROM chats c
     JOIN chat_participants cp ON c.id = cp.chat_id
     WHERE cp.user_id = ?
     ORDER BY c.updated_at DESC`,
    [userId],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
      } else {
        res.json(rows);
      }
    }
  );
});

app.get('/api/messages/:chatId', (req, res) => {
  const chatId = req.params.chatId;
  
  db.all(
    `SELECT m.*, u.name as sender_name 
     FROM messages m
     JOIN users u ON m.sender_id = u.id
     WHERE m.chat_id = ?
     ORDER BY m.sent_at ASC`,
    [chatId],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
      } else {
        res.json(rows);
      }
    }
  );
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Shutting down server...');
  db.close((err) => {
    if (err) {
      console.error('Error closing database:', err.message);
    } else {
      console.log('✅ Database connection closed');
    }
    process.exit(0);
  });
});

const PORT = process.env.PORT || 8000;
server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📱 Socket.IO ready for connections`);
  console.log(`🗄️  SQLite database: ${dbPath}`);
});
