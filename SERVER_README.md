# Chat App Server - SQLite Implementation

This is a Node.js server implementation for the Chat App using SQLite database instead of MongoDB.

## Features

- **SQLite Database**: Lightweight, file-based database perfect for university projects
- **Socket.IO**: Real-time bidirectional communication
- **RESTful API**: HTTP endpoints for data retrieval
- **User Management**: User registration and status tracking
- **Chat System**: Individual and group chat support
- **Message Types**: Support for text, image, video, audio, and file messages
- **Sample Data**: Pre-populated with test users and chats

## Database Schema

### Tables:
1. **users** - User information and status
2. **chats** - Chat rooms (individual/group)
3. **chat_participants** - Many-to-many relationship for chat members
4. **messages** - All chat messages with metadata

## Installation & Setup

1. **Install Dependencies:**
   ```bash
   npm install
   ```

2. **Start the Server:**
   ```bash
   npm start
   ```
   
   Or for development with auto-restart:
   ```bash
   npm run dev
   ```

3. **Database:**
   - SQLite database file (`chatapp.db`) will be created automatically
   - Sample data is inserted on first run
   - Database is located in the project root directory

## API Endpoints

- `GET /api/users` - Get all users
- `GET /api/chats/:userId` - Get user's chats
- `GET /api/messages/:chatId` - Get messages for a chat

## Socket.IO Events

### Client to Server:
- `signin` - User authentication with user ID
- `message` - Send a message

### Server to Client:
- `message` - Receive a message

## Configuration

- **Server Port**: 8000 (configurable via PORT environment variable)
- **Database**: SQLite file-based database
- **CORS**: Enabled for all origins (adjust for production)

## Flutter App Connection

The Flutter app connects to `http://10.0.2.2:8000` for Android emulator or `http://localhost:8000` for other platforms.

## Development Notes

- Database tables are created automatically on server start
- Sample users and chats are inserted if database is empty
- All database operations use prepared statements for security
- Graceful shutdown handling for database connections

## Sample Users (Auto-created)

1. John Doe (+1234567890)
2. Jane Smith (+1234567891)
3. Mike Johnson (+1234567892)
4. Sarah Wilson (+1234567893)

## University Project Notes

This implementation uses SQLite as requested for university requirements:
- ✅ SQLite database (instead of MongoDB)
- ✅ File-based storage (no external database server needed)
- ✅ SQL queries and relationships
- ✅ Proper database schema with foreign keys
- ✅ Sample data for testing and demonstration
