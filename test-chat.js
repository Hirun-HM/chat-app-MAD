const io = require('socket.io-client');

console.log('🧪 Testing Real-time Chat Between Two Users');
console.log('==========================================\n');

// Create two socket connections to simulate two users
const user1Socket = io('http://localhost:8000', {
  transports: ['websocket']
});

const user2Socket = io('http://localhost:8000', {
  transports: ['websocket']
});

let user1Connected = false;
let user2Connected = false;

// User 1 (John Doe - ID: 1)
user1Socket.on('connect', () => {
  console.log('👤 User 1 (John Doe) connected');
  user1Socket.emit('signin', 1);
  user1Connected = true;
  
  // Request chat history
  user1Socket.emit('get_chat_history', {
    sourceId: 1,
    targetId: 2
  });
  
  checkAndStartTest();
});

user1Socket.on('message', (msg) => {
  console.log('📨 User 1 received:', msg.message);
});

user1Socket.on('chat_history', (data) => {
  console.log(`📜 User 1 received chat history: ${data.messages.length} messages`);
  if (data.messages.length > 0) {
    data.messages.forEach((msg, index) => {
      console.log(`   ${index + 1}. [${msg.messageType}] ${msg.message}`);
    });
  }
});

// User 2 (Jane Smith - ID: 2)
user2Socket.on('connect', () => {
  console.log('👤 User 2 (Jane Smith) connected');
  user2Socket.emit('signin', 2);
  user2Connected = true;
  
  // Request chat history
  user2Socket.emit('get_chat_history', {
    sourceId: 2,
    targetId: 1
  });
  
  checkAndStartTest();
});

user2Socket.on('message', (msg) => {
  console.log('📨 User 2 received:', msg.message);
});

user2Socket.on('chat_history', (data) => {
  console.log(`📜 User 2 received chat history: ${data.messages.length} messages`);
  if (data.messages.length > 0) {
    data.messages.forEach((msg, index) => {
      console.log(`   ${index + 1}. [${msg.messageType}] ${msg.message}`);
    });
  }
});

function checkAndStartTest() {
  if (user1Connected && user2Connected) {
    console.log('\n🚀 Both users connected! Starting message test...\n');
    
    // Wait a bit then start sending test messages
    setTimeout(() => {
      console.log('💬 User 1 sending message to User 2...');
      user1Socket.emit('message', {
        message: 'Hello Jane! This is a test message from John.',
        sourceId: 1,
        targetId: 2,
        path: ''
      });
    }, 1000);
    
    setTimeout(() => {
      console.log('💬 User 2 replying to User 1...');
      user2Socket.emit('message', {
        message: 'Hi John! I received your message. This is Jane replying.',
        sourceId: 2,
        targetId: 1,
        path: ''
      });
    }, 2000);
    
    setTimeout(() => {
      console.log('💬 User 1 sending another message...');
      user1Socket.emit('message', {
        message: 'Great! Real-time messaging is working perfectly! 🎉',
        sourceId: 1,
        targetId: 2,
        path: ''
      });
    }, 3000);
    
    // Close connections after test
    setTimeout(() => {
      console.log('\n✅ Test completed! Disconnecting users...');
      user1Socket.disconnect();
      user2Socket.disconnect();
      
      setTimeout(() => {
        console.log('\n📊 Check database with: npm run inspect-db');
        console.log('🔄 Restart this test with: node test-chat.js');
        process.exit(0);
      }, 1000);
    }, 5000);
  }
}

// Error handling
user1Socket.on('connect_error', (err) => {
  console.error('❌ User 1 connection error:', err.message);
});

user2Socket.on('connect_error', (err) => {
  console.error('❌ User 2 connection error:', err.message);
});

console.log('🔄 Connecting users to server...');
