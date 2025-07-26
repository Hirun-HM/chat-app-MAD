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
      createMessageReadStatusTable();
    }
  });
}

// Create message read status table
function createMessageReadStatusTable() {
  db.run(`
    CREATE TABLE IF NOT EXISTS message_read_status (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      read_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (message_id) REFERENCES messages (id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users (id),
      UNIQUE(message_id, user_id)
    )
  `, (err) => {
    if (err) {
      console.error('Error creating message_read_status table:', err.message);
    } else {
      console.log('✅ Message read status table ready');
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

  // Handle user entering a specific chat
  socket.on('enter_chat', (data) => {
    const { userId, chatId } = data;
    console.log(`👤 User ${userId} entered chat ${chatId}`);
    
    // Store current chat for the user
    socket.currentChatId = chatId;
    
    // Mark all messages in this chat as read by this user
    markMessagesAsRead(userId, chatId);
    
    // Notify other users in the chat that this user is online in this chat
    socket.to(`chat_${chatId}`).emit('user_entered_chat', {
      userId: userId,
      chatId: chatId
    });
  });

  // Handle user leaving a specific chat
  socket.on('leave_chat', (data) => {
    const { userId, chatId } = data;
    console.log(`👤 User ${userId} left chat ${chatId}`);
    
    // Clear current chat for the user
    socket.currentChatId = null;
    
    // Notify other users in the chat that this user left
    socket.to(`chat_${chatId}`).emit('user_left_chat', {
      userId: userId,
      chatId: chatId
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
                
                // Get all participants in this chat
                getChatParticipants(chatId, (participants) => {
                  // Broadcast message to all participants in the chat
                  participants.forEach(participantId => {
                    const participantSocketId = connectedUsers.get(participantId);
                    if (participantSocketId && participantId !== sourceId) {
                      const participantSocket = io.sockets.sockets.get(participantSocketId);
                      if (participantSocket) {
                        // Check if user is currently in this chat
                        const isInChat = participantSocket.currentChatId === chatId;
                        
                        // Send message
                        participantSocket.emit('message', {
                          id: messageData.id,
                          message: messageData.message_text,
                          path: messageData.file_path || '',
                          sender: messageData.sender_name,
                          senderId: messageData.sender_id,
                          sentAt: messageData.sent_at,
                          type: messageData.message_type,
                          chatId: chatId
                        });
                        
                        // Send notification if user is not in this chat
                        if (!isInChat) {
                          participantSocket.emit('notification', {
                            type: 'new_message',
                            chatId: chatId,
                            sender: messageData.sender_name,
                            message: messageData.message_text,
                            sentAt: messageData.sent_at
                          });
                          
                          // Also emit chat list update event
                          participantSocket.emit('chat_list_update', {
                            chatId: chatId,
                            lastMessage: messageData.message_text,
                            lastSender: messageData.sender_name,
                            time: messageData.sent_at
                          });
                          
                          console.log(`🔔 Notification sent to user ${participantId} from ${messageData.sender_name}`);
                        } else {
                          // User is in chat, just update their chat list
                          participantSocket.emit('chat_list_update', {
                            chatId: chatId,
                            lastMessage: messageData.message_text,
                            lastSender: messageData.sender_name,
                            time: messageData.sent_at
                          });
                        }
                      }
                    }
                  });
                });
                
                // Also emit to sender for confirmation
                socket.emit('message_sent', {
                  id: messageData.id,
                  message: messageData.message_text,
                  path: messageData.file_path || '',
                  sentAt: messageData.sent_at,
                  chatId: chatId
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

// Helper function to format time
function formatTime(timestamp) {
  const date = new Date(timestamp);
  const now = new Date();
  
  // If it's today, show time
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit',
      hour12: false 
    });
  }
  
  // If it's this week, show day name
  const daysDiff = Math.floor((now - date) / (1000 * 60 * 60 * 24));
  if (daysDiff < 7) {
    return date.toLocaleDateString('en-US', { weekday: 'short' });
  }
  
  // Otherwise show date
  return date.toLocaleDateString('en-US', { 
    month: 'short', 
    day: 'numeric' 
  });
}

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

// Helper function to get chat participants
function getChatParticipants(chatId, callback) {
  db.all(
    "SELECT user_id FROM chat_participants WHERE chat_id = ?",
    [chatId],
    (err, rows) => {
      if (err) {
        console.error('Error getting chat participants:', err.message);
        callback([]);
      } else {
        callback(rows.map(row => row.user_id));
      }
    }
  );
}

// Helper function to mark messages as read
function markMessagesAsRead(userId, chatId) {
  // Get all unread messages in this chat for this user
  db.all(
    `SELECT m.id 
     FROM messages m 
     WHERE m.chat_id = ? 
     AND m.sender_id != ? 
     AND m.id NOT IN (
       SELECT mrs.message_id 
       FROM message_read_status mrs 
       WHERE mrs.user_id = ?
     )`,
    [chatId, userId, userId],
    (err, messages) => {
      if (err) {
        console.error('Error getting unread messages:', err.message);
        return;
      }
      
      // Mark each message as read
      messages.forEach(message => {
        db.run(
          `INSERT OR IGNORE INTO message_read_status (message_id, user_id) 
           VALUES (?, ?)`,
          [message.id, userId],
          (err) => {
            if (err) {
              console.error('Error marking message as read:', err.message);
            }
          }
        );
      });
      
      if (messages.length > 0) {
        console.log(`✅ Marked ${messages.length} messages as read for user ${userId} in chat ${chatId}`);
      }
    }
  );
}

// API endpoint to create a new group
app.post('/api/groups', (req, res) => {
  const { name, createdBy, participants } = req.body;
  
  if (!name || !createdBy || !participants || participants.length === 0) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  
  // Create the group chat
  db.run(
    "INSERT INTO chats (name, type, created_by) VALUES (?, 'group', ?)",
    [name, createdBy],
    function(err) {
      if (err) {
        console.error('Error creating group:', err.message);
        res.status(500).json({ error: 'Failed to create group' });
        return;
      }
      
      const groupId = this.lastID;
      console.log(`✅ Created group: ${name} with ID: ${groupId}`);
      
      // Add creator as admin
      db.run(
        "INSERT INTO chat_participants (chat_id, user_id, is_admin) VALUES (?, ?, 1)",
        [groupId, createdBy],
        (err) => {
          if (err) {
            console.error('Error adding group creator:', err.message);
          }
        }
      );
      
      // Add other participants
      participants.forEach(participantId => {
        if (participantId !== createdBy) {
          db.run(
            "INSERT INTO chat_participants (chat_id, user_id, is_admin) VALUES (?, ?, 0)",
            [groupId, participantId],
            (err) => {
              if (err) {
                console.error('Error adding participant:', err.message);
              }
            }
          );
        }
      });
      
      res.json({
        success: true,
        groupId: groupId,
        name: name,
        type: 'group',
        participants: participants
      });
    }
  );
});

// API endpoint to mark messages as read
app.post('/api/messages/mark-read/:chatId/:userId', (req, res) => {
  const { chatId, userId } = req.params;
  
  // Mark all unread messages in this chat as read
  db.all(
    `SELECT m.id 
     FROM messages m 
     WHERE m.chat_id = ? 
     AND m.sender_id != ? 
     AND m.id NOT IN (
       SELECT mrs.message_id 
       FROM message_read_status mrs 
       WHERE mrs.user_id = ?
     )`,
    [chatId, userId, userId],
    (err, messages) => {
      if (err) {
        console.error('Error getting unread messages:', err.message);
        res.status(500).json({ error: 'Failed to mark messages as read' });
        return;
      }
      
      // Mark each message as read
      let completed = 0;
      if (messages.length === 0) {
        res.json({ success: true, markedCount: 0 });
        return;
      }
      
      messages.forEach(message => {
        db.run(
          `INSERT OR IGNORE INTO message_read_status (message_id, user_id) 
           VALUES (?, ?)`,
          [message.id, userId],
          (err) => {
            completed++;
            if (err) {
              console.error('Error marking message as read:', err.message);
            }
            
            if (completed === messages.length) {
              console.log(`✅ Marked ${messages.length} messages as read for user ${userId} in chat ${chatId}`);
              res.json({ success: true, markedCount: messages.length });
            }
          }
        );
      });
    }
  );
});

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
    `SELECT DISTINCT 
       c.id, 
       c.name, 
       c.type, 
       c.icon, 
       c.updated_at,
       (SELECT m.message_text 
        FROM messages m 
        WHERE m.chat_id = c.id 
        ORDER BY m.sent_at DESC 
        LIMIT 1) as last_message,
       (SELECT m.sent_at 
        FROM messages m 
        WHERE m.chat_id = c.id 
        ORDER BY m.sent_at DESC 
        LIMIT 1) as last_message_time,
       (SELECT u.name 
        FROM messages m 
        JOIN users u ON m.sender_id = u.id 
        WHERE m.chat_id = c.id 
        ORDER BY m.sent_at DESC 
        LIMIT 1) as last_sender_name,
       (SELECT COUNT(*) 
        FROM messages m 
        WHERE m.chat_id = c.id 
        AND m.sender_id != ? 
        AND m.id NOT IN (
          SELECT mrs.message_id 
          FROM message_read_status mrs 
          WHERE mrs.user_id = ?
        )) as unread_count,
       -- For individual chats, get the other participant's name
       (CASE 
        WHEN c.type = 'individual' THEN 
          (SELECT u.name 
           FROM chat_participants cp 
           JOIN users u ON cp.user_id = u.id 
           WHERE cp.chat_id = c.id AND cp.user_id != ?)
        ELSE c.name 
       END) as display_name
     FROM chats c
     JOIN chat_participants cp ON c.id = cp.chat_id
     WHERE cp.user_id = ?
     ORDER BY COALESCE(last_message_time, c.updated_at) DESC`,
    [userId, userId, userId, userId],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
      } else {
        // Format the response with better time formatting
        const formattedRows = rows.map(row => ({
          ...row,
          time: row.last_message_time ? formatTime(row.last_message_time) : formatTime(row.updated_at),
          currentMessage: row.last_message || 'No messages yet',
          name: row.display_name || row.name || 'Unknown Chat'
        }));
        res.json(formattedRows);
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
