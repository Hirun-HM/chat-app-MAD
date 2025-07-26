const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const multer = require('multer');
const fs = require('fs');
const QRCode = require('qrcode');

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, 'public', 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueName = uuidv4() + path.extname(file.originalname);
    cb(null, uniqueName);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed!'), false);
    }
  }
});

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
      
      // Insert sample users with Sri Lankan phone numbers
      const users = [
        { name: 'John Doe', phone: '+94719162128', avatar: 'person.svg' },
        { name: 'Jane Smith', phone: '+94741377070', avatar: 'person.svg' },
        { name: 'Mike Johnson', phone: '+94764532890', avatar: 'person.svg' },
        { name: 'Sarah Wilson', phone: '+94774087556', avatar: 'person.svg' },
        { name: 'Alex Fernando', phone: '+94772147171', avatar: 'person.svg' }
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
    console.log(`👤 User ${userId} entered chat ${chatId} - marking messages as read`);
    
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

  // Handle getting chat history by chat ID
  socket.on('get_chat_history_by_id', (data) => {
    const { chatId, userId } = data;
    console.log(`📜 Getting chat history for chat ${chatId} by user ${userId}`);
    
    if (!chatId || !userId) {
      console.error('❌ Invalid chat history request:', data);
      return;
    }
    
    // Verify user is a participant in this chat
    db.get(
      "SELECT 1 FROM chat_participants WHERE chat_id = ? AND user_id = ?",
      [chatId, userId],
      (err, participant) => {
        if (err) {
          console.error('Error checking chat participant:', err.message);
          return;
        }
        
        if (!participant) {
          console.error(`❌ User ${userId} is not a participant in chat ${chatId}`);
          return;
        }
        
        // Get all messages for this chat with read status
        db.all(
          `SELECT m.*, u.name as sender_name,
                  CASE WHEN mrs.user_id IS NOT NULL THEN 1 ELSE 0 END as is_read_by_current_user,
                  -- For messages sent by current user, check if read by at least one other participant
                  CASE 
                    WHEN m.sender_id = ? THEN (
                      SELECT COUNT(*) > 0 
                      FROM message_read_status mrs2 
                      WHERE mrs2.message_id = m.id 
                      AND mrs2.user_id != ?
                    )
                    ELSE 0
                  END as is_read_by_others
           FROM messages m
           JOIN users u ON m.sender_id = u.id
           LEFT JOIN message_read_status mrs ON m.id = mrs.message_id AND mrs.user_id = ?
           WHERE m.chat_id = ?
           ORDER BY m.sent_at ASC`,
          [userId, userId, userId, chatId],
          (err, messages) => {
            if (err) {
              console.error('Error getting chat history:', err.message);
              return;
            }
            
            console.log(`📤 Sending ${messages.length} messages to user ${userId} for chat ${chatId}`);
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
                // For destination messages (received), use is_read_by_current_user
                // For source messages (sent), use is_read_by_others
                isRead: msg.sender_id === userId ? msg.is_read_by_others === 1 : msg.is_read_by_current_user === 1,
                // Determine if this message is from the current user
                messageType: msg.sender_id === userId ? 'source' : 'destination'
              }))
            });
          }
        );
      }
    );
  });

  // Handle joining a specific chat room
  socket.on('join_chat', (data) => {
    const { chatId, userId } = data;
    console.log(`👤 User ${userId} joining chat room: chat_${chatId}`);
    
    if (!chatId || !userId) {
      console.error('❌ Invalid join chat request:', data);
      return;
    }
    
    // Verify user is a participant in this chat
    db.get(
      "SELECT 1 FROM chat_participants WHERE chat_id = ? AND user_id = ?",
      [chatId, userId],
      (err, participant) => {
        if (err) {
          console.error('Error checking chat participant:', err.message);
          return;
        }
        
        if (!participant) {
          console.error(`❌ User ${userId} is not authorized to join chat ${chatId}`);
          return;
        }
        
        // Join the chat room
        socket.join(`chat_${chatId}`);
        console.log(`✅ User ${userId} joined chat room: chat_${chatId}`);
        
        // Notify other users in the chat
        socket.to(`chat_${chatId}`).emit('user_joined_chat', {
          userId: userId,
          chatId: chatId
        });
      }
    );
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
                
                // Update sender's chat list too
                socket.emit('chat_list_update', {
                  chatId: chatId,
                  lastMessage: messageData.message_text,
                  lastSender: messageData.sender_name,
                  time: messageData.sent_at
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

  // Handle sending messages to a specific chat
  socket.on('send_chat_message', (data) => {
    console.log('📨 Received chat message:', data);
    
    const { message, senderId, chatId, path } = data;
    
    if (!message || !senderId || !chatId) {
      console.error('❌ Invalid message data:', data);
      return;
    }
    
    // Save message to database
    const messageType = path && path !== '' ? getMessageType(path) : 'text';
    
    db.run(
      `INSERT INTO messages (chat_id, sender_id, message_text, message_type, file_path, sent_at) 
       VALUES (?, ?, ?, ?, ?, datetime('now'))`,
      [chatId, senderId, message, messageType, path || ''],
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
            
            // Broadcast message to all participants in the chat room
            io.to(`chat_${chatId}`).emit('message', {
              id: messageData.id,
              message: messageData.message_text,
              path: messageData.file_path || '',
              sender: messageData.sender_name,
              senderId: messageData.sender_id,
              sentAt: messageData.sent_at,
              type: messageData.message_type,
              chatId: chatId
            });
            
            // Confirm message sent to sender
            socket.emit('message_sent', {
              id: messageData.id,
              message: messageData.message_text,
              path: messageData.file_path || '',
              sentAt: messageData.sent_at,
              chatId: chatId
            });
            
            // Get all participants in this chat for notifications and chat list updates
            getChatParticipants(chatId, (participants) => {
              participants.forEach(participantId => {
                const participantSocketId = connectedUsers.get(participantId);
                if (participantSocketId) {
                  const participantSocket = io.sockets.sockets.get(participantSocketId);
                  if (participantSocket) {
                    // Check if user is currently in this chat
                    const isInChat = participantSocket.currentChatId === chatId;
                    
                    // Send notification if user is not in this chat
                    if (!isInChat && participantId !== senderId) {
                      participantSocket.emit('notification', {
                        type: 'new_message',
                        chatId: chatId,
                        sender: messageData.sender_name,
                        message: messageData.message_text,
                        sentAt: messageData.sent_at
                      });
                      
                      console.log(`🔔 Notification sent to user ${participantId} from ${messageData.sender_name}`);
                    }
                    
                    // Calculate unread count for this participant
                    db.get(
                      `SELECT COUNT(*) as unread_count
                       FROM messages m 
                       WHERE m.chat_id = ? 
                       AND m.sender_id != ? 
                       AND m.id NOT IN (
                         SELECT mrs.message_id 
                         FROM message_read_status mrs 
                         WHERE mrs.user_id = ?
                       )`,
                      [chatId, participantId, participantId],
                      (err, countResult) => {
                        if (err) {
                          console.error('Error calculating unread count:', err.message);
                          return;
                        }
                        
                        const unreadCount = isInChat ? 0 : (countResult?.unread_count || 0);
                        
                        // Check if this message (if sent by current participant) has been read
                        const isLastMessageFromCurrentUser = messageData.sender_id === participantId;
                        let lastMessageReadByOthers = false;
                        
                        if (isLastMessageFromCurrentUser) {
                          // Check if the message has been read by others
                          db.get(
                            `SELECT COUNT(*) > 0 as is_read 
                             FROM message_read_status mrs 
                             WHERE mrs.message_id = ? 
                             AND mrs.user_id != ?`,
                            [messageData.id, participantId],
                            (err, readResult) => {
                              if (!err && readResult) {
                                lastMessageReadByOthers = readResult.is_read === 1;
                              }
                              
                              // Always send chat list update with all information
                              participantSocket.emit('chat_list_update', {
                                chatId: chatId,
                                lastMessage: messageData.message_text,
                                lastSender: messageData.sender_name,
                                senderId: messageData.sender_id,
                                time: messageData.sent_at,
                                unreadCount: unreadCount,
                                isLastMessageFromCurrentUser: isLastMessageFromCurrentUser,
                                lastMessageReadByOthers: lastMessageReadByOthers
                              });
                              
                              console.log(`📋 Chat list update sent to user ${participantId}, unread: ${unreadCount}, read by others: ${lastMessageReadByOthers}`);
                            }
                          );
                        } else {
                          // Message is from someone else, send update immediately
                          participantSocket.emit('chat_list_update', {
                            chatId: chatId,
                            lastMessage: messageData.message_text,
                            lastSender: messageData.sender_name,
                            senderId: messageData.sender_id,
                            time: messageData.sent_at,
                            unreadCount: unreadCount,
                            isLastMessageFromCurrentUser: isLastMessageFromCurrentUser,
                            lastMessageReadByOthers: false
                          });
                          
                          console.log(`📋 Chat list update sent to user ${participantId}, unread: ${unreadCount}`);
                        }
                      }
                    );
                  }
                }
              });
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

  // Handle message read status update
  socket.on('message_read', (data) => {
    const { messageId, userId, chatId } = data;
    console.log(`👁️ Message ${messageId} read by user ${userId} in chat ${chatId}`);
    
    // Update message read status
    db.run(
      `INSERT OR IGNORE INTO message_read_status (message_id, user_id, read_at) 
       VALUES (?, ?, datetime('now'))`,
      [messageId, userId],
      function(err) {
        if (err) {
          console.error('Error updating message read status:', err.message);
        } else {
          console.log(`✅ Message ${messageId} marked as read by user ${userId}`);
          
          // Notify the sender about the read status
          db.get(
            "SELECT sender_id FROM messages WHERE id = ?",
            [messageId],
            (err, message) => {
              if (err) {
                console.error('Error getting message sender:', err.message);
                return;
              }
              
              if (message && message.sender_id !== userId) {
                const senderSocketId = connectedUsers.get(message.sender_id);
                if (senderSocketId) {
                  const senderSocket = io.sockets.sockets.get(senderSocketId);
                  if (senderSocket) {
                    senderSocket.emit('message_read_receipt', {
                      messageId: messageId,
                      readBy: userId,
                      chatId: chatId,
                      readAt: new Date().toISOString()
                    });
                  }
                }
              }
            }
          );
        }
      }
    );
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
  // First validate that both users exist
  db.all(
    "SELECT id FROM users WHERE id IN (?, ?)",
    [sourceId, targetId],
    (err, users) => {
      if (err) {
        console.error('Error validating users:', err.message);
        callback(null);
        return;
      }
      
      if (users.length !== 2) {
        console.error(`Invalid users: ${sourceId}, ${targetId}. Found: ${users.length} valid users`);
        callback(null);
        return;
      }
      
      // Now find or create chat between valid users
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
          `INSERT OR IGNORE INTO message_read_status (message_id, user_id, read_at) 
           VALUES (?, ?, datetime('now'))`,
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
      
      // Always emit unread count update to ensure UI is synced, regardless of whether there were messages to mark
      const userSocketId = connectedUsers.get(userId);
      if (userSocketId) {
        const userSocket = io.sockets.sockets.get(userSocketId);
        if (userSocket) {
          console.log(`📤 Sending unread count update to user ${userId} for chat ${chatId}: 0`);
          userSocket.emit('unread_count_update', {
            chatId: chatId,
            userId: userId,
            unreadCount: 0
          });
        }
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

// API endpoint to create or find individual chat
app.post('/api/chats/individual', (req, res) => {
  const { sourceId, targetId } = req.body;
  
  if (!sourceId || !targetId) {
    return res.status(400).json({ error: 'Missing required fields: sourceId, targetId' });
  }
  
  if (sourceId === targetId) {
    return res.status(400).json({ error: 'Cannot create chat with yourself' });
  }
  
  findOrCreateChat(sourceId, targetId, (chatId) => {
    if (chatId) {
      res.json({
        success: true,
        chatId: chatId,
        message: 'Chat ready for messaging'
      });
    } else {
      res.status(500).json({ error: 'Failed to create or find chat' });
    }
  });
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

// REST API endpoint for sending messages (for testing purposes)
app.post('/api/messages', (req, res) => {
  const { chatId, senderId, messageText, messageType = 'text', filePath = '' } = req.body;
  
  if (!chatId || !senderId || !messageText) {
    return res.status(400).json({ error: 'Missing required fields: chatId, senderId, messageText' });
  }
  
  // Save message to database
  db.run(
    `INSERT INTO messages (chat_id, sender_id, message_text, message_type, file_path, sent_at) 
     VALUES (?, ?, ?, ?, ?, datetime('now'))`,
    [chatId, senderId, messageText, messageType, filePath],
    function(err) {
      if (err) {
        console.error('Error saving message:', err.message);
        return res.status(500).json({ error: 'Failed to save message' });
      }
      
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
            return res.status(500).json({ error: 'Failed to retrieve message' });
          }
          
          // Update chat's last message timestamp
          db.run(
            "UPDATE chats SET updated_at = datetime('now') WHERE id = ?",
            [chatId],
            (err) => {
              if (err) {
                console.error('Error updating chat timestamp:', err.message);
              }
            }
          );
          
          // Get all participants in this chat for real-time updates
          getChatParticipants(chatId, (participants) => {
            // Broadcast message to all connected participants
            participants.forEach(participantId => {
              const participantSocketId = connectedUsers.get(participantId);
              if (participantSocketId) {
                const participantSocket = io.sockets.sockets.get(participantSocketId);
                if (participantSocket) {
                  // Check if user is currently in this chat
                  const isInChat = participantSocket.currentChatId === chatId;
                  
                  if (participantId !== senderId) {
                    // Send message to other participants
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
                    }
                  }
                  
                  // Update chat list for all participants
                  participantSocket.emit('chat_list_update', {
                    chatId: chatId,
                    lastMessage: messageData.message_text,
                    lastSender: messageData.sender_name,
                    time: messageData.sent_at
                  });
                }
              }
            });
          });
          
          res.json({
            success: true,
            message: {
              id: messageData.id,
              chat_id: messageData.chat_id,
              sender_id: messageData.sender_id,
              message_text: messageData.message_text,
              message_type: messageData.message_type,
              file_path: messageData.file_path,
              sent_at: messageData.sent_at,
              sender_name: messageData.sender_name
            }
          });
        }
      );
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
        ORDER BY m.sent_at DESC, m.id DESC 
        LIMIT 1) as last_message,
       (SELECT m.sent_at 
        FROM messages m 
        WHERE m.chat_id = c.id 
        ORDER BY m.sent_at DESC, m.id DESC 
        LIMIT 1) as last_message_time,
       (SELECT u.name 
        FROM messages m 
        JOIN users u ON m.sender_id = u.id 
        WHERE m.chat_id = c.id 
        ORDER BY m.sent_at DESC, m.id DESC 
        LIMIT 1) as last_sender_name,
       (SELECT m.sender_id 
        FROM messages m 
        WHERE m.chat_id = c.id 
        ORDER BY m.sent_at DESC, m.id DESC 
        LIMIT 1) as last_sender_id,
       -- Check if last message (if sent by current user) has been read by others
       (SELECT CASE 
          WHEN last_msg.sender_id = ? THEN 
            (SELECT COUNT(*) > 0 
             FROM message_read_status mrs 
             WHERE mrs.message_id = last_msg.id 
             AND mrs.user_id != ?)
          ELSE 0
        END
        FROM (SELECT m.id, m.sender_id 
              FROM messages m 
              WHERE m.chat_id = c.id 
              ORDER BY m.sent_at DESC, m.id DESC 
              LIMIT 1) as last_msg) as last_message_read_by_others,
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
     AND EXISTS (
       SELECT 1 FROM messages m WHERE m.chat_id = c.id
     )
     ORDER BY COALESCE(last_message_time, c.updated_at) DESC`,
    [userId, userId, userId, userId, userId, userId],
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
      } else {
        // Format the response with better time formatting
        const formattedRows = rows.map(row => ({
          ...row,
          time: row.last_message_time ? formatTime(row.last_message_time) : formatTime(row.updated_at),
          currentMessage: row.last_message || 'No messages yet',
          name: row.display_name || row.name || 'Unknown Chat',
          lastSenderId: row.last_sender_id,
          lastMessageReadByOthers: row.last_message_read_by_others === 1,
          isLastMessageFromCurrentUser: row.last_sender_id === parseInt(userId)
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

// API endpoint to generate QR code for user contact
app.get('/api/qr-code/:userId', async (req, res) => {
  const userId = req.params.userId;
  
  try {
    // Get user details
    db.get(
      "SELECT id, name, phone FROM users WHERE id = ?",
      [userId],
      async (err, user) => {
        if (err) {
          res.status(500).json({ error: err.message });
          return;
        }
        
        if (!user) {
          res.status(404).json({ error: 'User not found' });
          return;
        }
        
        // Create WhatsApp link for QR code
        const whatsAppLink = `https://wa.me/${user.phone.replace('+', '')}`;
        
        // Also create contact data as backup
        const contactData = {
          type: 'contact',
          userId: user.id,
          name: user.name,
          phone: user.phone,
          whatsappUrl: whatsAppLink
        };
        
        try {
          // Generate QR code with WhatsApp link
          const qrCodeDataURL = await QRCode.toDataURL(whatsAppLink, {
            width: 300,
            margin: 2,
            color: {
              dark: '#000000',
              light: '#FFFFFF'
            }
          });
          
          res.json({
            success: true,
            qrCode: qrCodeDataURL,
            contactData: contactData,
            whatsappUrl: whatsAppLink
          });
        } catch (qrError) {
          console.error('QR Code generation error:', qrError);
          res.status(500).json({ error: 'Failed to generate QR code' });
        }
      }
    );
  } catch (error) {
    console.error('QR Code endpoint error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API endpoint to find user by phone number
app.get('/api/users/phone/:phoneNumber', (req, res) => {
  const phoneNumber = req.params.phoneNumber;
  
  try {
    db.get(
      "SELECT id, name, phone, avatar FROM users WHERE phone = ?",
      [phoneNumber],
      (err, user) => {
        if (err) {
          console.error('Database error:', err);
          res.status(500).json({ error: err.message });
          return;
        }
        
        if (!user) {
          res.status(404).json({ error: 'User not found' });
          return;
        }
        
        res.json({
          id: user.id,
          name: user.name,
          phoneNumber: user.phone,
          avatar: user.avatar
        });
      }
    );
  } catch (error) {
    console.error('Find user by phone endpoint error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// API endpoint to upload user avatar
app.post('/api/users/:userId/avatar', upload.single('avatar'), (req, res) => {
  const userId = req.params.userId;
  const file = req.file;
  
  if (!file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  
  // Update user avatar in the database
  db.run(
    "UPDATE users SET avatar = ? WHERE id = ?",
    [file.filename, userId],
    function(err) {
      if (err) {
        console.error('Error updating avatar:', err.message);
        res.status(500).json({ error: 'Failed to update avatar' });
      } else {
        console.log(`✅ Updated avatar for user ID: ${userId}`);
        res.json({
          success: true,
          avatar: file.filename
        });
      }
    }
  );
});

// Group icon upload endpoint
app.post('/api/groups/:groupId/icon', upload.single('icon'), (req, res) => {
  const groupId = req.params.groupId;
  const file = req.file;
  
  if (!file) {
    return res.status(400).json({ error: 'No file uploaded' });
  }
  
  // Update group icon in the database
  db.run(
    "UPDATE chats SET icon = ? WHERE id = ? AND type = 'group'",
    [file.filename, groupId],
    function(err) {
      if (err) {
        console.error('Error updating group icon:', err.message);
        res.status(500).json({ error: 'Failed to update group icon' });
      } else {
        console.log(`✅ Updated icon for group ID: ${groupId}`);
        res.json({
          success: true,
          icon: file.filename
        });
      }
    }
  );
});

// API endpoint to delete a chat
app.delete('/api/chats/:chatId/:userId', (req, res) => {
  const { chatId, userId } = req.params;
  
  // First check if user is a participant in this chat
  db.get(
    "SELECT * FROM chat_participants WHERE chat_id = ? AND user_id = ?",
    [chatId, userId],
    (err, participant) => {
      if (err) {
        console.error('Error checking participant:', err.message);
        return res.status(500).json({ error: 'Database error' });
      }
      
      if (!participant) {
        return res.status(403).json({ error: 'User not authorized to delete this chat' });
      }
      
      // Check chat type
      db.get(
        "SELECT type, created_by FROM chats WHERE id = ?",
        [chatId],
        (err, chat) => {
          if (err) {
            console.error('Error fetching chat:', err.message);
            return res.status(500).json({ error: 'Database error' });
          }
          
          if (!chat) {
            return res.status(404).json({ error: 'Chat not found' });
          }
          
          if (chat.type === 'group' && chat.created_by !== parseInt(userId)) {
            // For groups, only the creator can delete the entire group
            // Others can only leave the group
            db.run(
              "DELETE FROM chat_participants WHERE chat_id = ? AND user_id = ?",
              [chatId, userId],
              function(err) {
                if (err) {
                  console.error('Error leaving group:', err.message);
                  return res.status(500).json({ error: 'Failed to leave group' });
                }
                
                console.log(`✅ User ${userId} left group ${chatId}`);
                res.json({ success: true, action: 'left_group' });
              }
            );
          } else {
            // For individual chats or group creator, delete the entire chat
            db.run(
              "DELETE FROM chats WHERE id = ?",
              [chatId],
              function(err) {
                if (err) {
                  console.error('Error deleting chat:', err.message);
                  return res.status(500).json({ error: 'Failed to delete chat' });
                }
                
                console.log(`✅ Chat ${chatId} deleted by user ${userId}`);
                res.json({ success: true, action: 'deleted_chat' });
              }
            );
          }
        }
      );
    }
  );
});

// QR code generation endpoint
app.post('/api/qrcode', (req, res) => {
  const { text } = req.body;
  
  if (!text) {
    return res.status(400).json({ error: 'No text provided for QR code' });
  }
  
  // Generate QR code
  QRCode.toDataURL(text, { errorCorrectionLevel: 'H' }, (err, url) => {
    if (err) {
      console.error('Error generating QR code:', err.message);
      return res.status(500).json({ error: 'Failed to generate QR code' });
    }
    
    res.json({
      success: true,
      qrCodeUrl: url
    });
  });
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
