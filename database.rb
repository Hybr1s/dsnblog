require 'sqlite3'

class Database

    def initialize 
        @db = SQLite3::Database.new "dsnblog.db"
        begin
            @db.execute "CREATE TABLE IF NOT EXISTS authors(
                            name TEXT PRIMARY KEY,
                            mail TEXT UNIQUE
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS friends(
                            name TEXT PRIMARY KEY,
                            url TEXT
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS comment_authors(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            name TEXT,
                            mail TEXT,
                            url TEXT,
                            UNIQUE (name, mail)
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS comments(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            replyToEntry INTEGER,
                            replyToComment INTEGER,
                            body TEXT,
                            title TEXT,
                            author TEXT,
                            type TEXT DEFAULT 'comment',
                            status TEXT DEFAULT 'approved',
                            date INTEGER DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (replyToEntry) REFERENCES entries(id),
                            FOREIGN KEY (replyToComment) REFERENCES comments(id),
                            FOREIGN KEY (author) REFERENCES comment_authors(id) ON UPDATE CASCADE
                            );"
            @db.execute "CREATE TABLE IF NOT EXISTS entries(
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            body TEXT,
                            title TEXT,
                            author TEXT,
                            date INTEGER DEFAULT CURRENT_TIMESTAMP,
                            FOREIGN KEY (author) REFERENCES authors(name) ON UPDATE CASCADE
                            );"
            @db.execute "PRAGMA foreign_keys = ON;"
            @db.results_as_hash = true
        rescue => error
            puts error
        end
    end

    def getEntries(page, amount)
        entries = []
        begin
            totalEntries = @db.execute("SELECT COUNT(id) from entries")[0]["COUNT(id)"]
            totalPages = (totalEntries.to_f / amount).ceil;
            totalPages = totalPages <= 0 ? 1 : totalPages
            case page
                when -1 then
                    # on frontpage, we have no real index
                    offset = 0
                    limit = amount
                when totalPages - 1 then
                    offset = amount
                    limit = (totalEntries - ((totalPages - 2) * amount)) - amount
                else
                    offset = totalEntries - (amount * page)
                    limit = amount
            end
            
            @db.execute("SELECT id, title, body, author, date FROM entries ORDER BY date DESC LIMIT ?,?;", offset, limit) do |row|
                entry = Entry.new()
                entry.body = row["body"]
                entry.id = row["id"]
                entry.title = row["title"]
                entry.date = row["date"]
                entry.author = row["author"]
                entries.push(entry)
            end
        rescue => error
            puts error
        end
        return entries
    end

    def getTotalPages()
        amount = 5
        totalEntries = @db.execute("SELECT COUNT(id) from entries")[0]["COUNT(id)"]
        totalPages = (totalEntries.to_f / amount).ceil;
    end

    def addEntry(entry)
        begin
            @db.execute("INSERT INTO entries(title, body, author) VALUES(?, ?, ?);", entry.title, entry.body, entry.author)
        rescue => error
            puts error
        end
        return @db.last_insert_row_id()
    end

    def editEntry(entry)
        begin
            @db.execute("UPDATE entries SET title = ?, body = ? WHERE id = ?;", entry.title, entry.body, entry.id)
        rescue => error
            puts error
            return false
        end
        return true
    end

    def deleteEntry(id)
        begin
            @db.execute("DELETE FROM entries WHERE id = ?", id)
        rescue => error
            puts "error in deleting entries: #{error}"
        end
    end

    def getEntryData(id)
        begin
            return @db.execute("SELECT title, body, author, date FROM entries WHERE id == ?;", id)[0]
        rescue => error
            puts error
        end
    end

    def addComment(comment)
        begin
            @db.execute("INSERT OR REPLACE INTO comment_authors(name, mail, url)
                            VALUES(?, ?, ?);",
                            comment.author.name, comment.author.mail, comment.author.url)
            commentAuthorID = @db.last_insert_row_id()
        rescue => error
            puts "error in inserting comment_author: #{error}"
            begin
                commentAuthorID = @db.get_first_value("SELECT id FROM comment_authors WHERE name = ? and mail = ?", comment.author.name, comment.author.mail)
            rescue => error
                puts "error in selecting comment_author: #{error}"
            end
        end
        
        puts commentAuthorID
        puts comment.replyToEntry
        puts comment.replyToComment
        begin
             @db.execute("INSERT INTO comments(replyToEntry, replyToComment, body, author, type, status, title)
                            VALUES(?, ?, ?, ?, ?, ?, ?);",
                            comment.replyToEntry, comment.replyToComment, comment.body, commentAuthorID, comment.type, comment.status, comment.title)
        rescue => error
            puts "error in inserting comment: #{error}"
        end
    end

    def deleteComment(comment)
        begin
            @db.execute("DELETE FROM comments WHERE id = ?", comment.id)
        rescue => error
            puts "error in deleting comment: #{error}"
        end
    end

    def getCommentsForEntry(id)
        comments = []
        begin
            @db.execute("SELECT comments.id FROM comments WHERE replyToEntry == ?;", id) do  |row|
                comments.push(Comment.new(row["id"]))
            end
        rescue => error
            puts error
        end
        return comments
    end

    def getCommentData(id)
        begin
            return @db.execute("SELECT name, url, mail, body, title, replyToComment, date
                            FROM comments INNER JOIN comment_authors ON comments.author = comment_authors.id
                        WHERE comments.id == ?;", id)[0]
        rescue => error
            puts error
        end
    end

    def getMails()
        begin
            return @db.execute("SELECT mail FROM authors;")
        rescue => error
            puts error
        end
    end

    def firstUse?
        begin
            mail = @db.execute("SELECT mail FROM authors;")
        rescue => error
            puts error
        end
        return mail.empty?
    end

    def addUser(name, mail)
        begin
            mail = @db.execute("INSERT INTO authors(name, mail) VALUES(?, ?);", name, mail)
        rescue => error
            puts error
        end
    end
    
    def addFriend(name, url)
        begin
            mail = @db.execute("INSERT INTO friends(name, url) VALUES(?, ?);", name, url)
        rescue => error
            puts error
        end
    end

    def getFriends()
        friends = []
        begin
            @db.execute("SELECT name, url FROM friends;") do |row|
                friend = Friend.new()
                friend.name = row["name"]
                friend.url = row["url"]
                friends.push(friend)
            end
        rescue => error
            puts error
        end
        return friends
    end

    def getAdmin()
        begin
            return @db.execute("SELECT name FROM authors LIMIT 1;")[0]['name']
        rescue => error
            puts error
        end
    end
    

end
