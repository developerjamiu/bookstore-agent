import 'package:sqlite3/sqlite3.dart';

Database createSeedDatabase({String? path}) {
  final db = path != null ? sqlite3.open(path) : sqlite3.openInMemory();

  db.execute('''
    CREATE TABLE authors (
      AuthorId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL,
      Country TEXT
    );

    CREATE TABLE publishers (
      PublisherId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL,
      City TEXT
    );

    CREATE TABLE genres (
      GenreId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL
    );

    CREATE TABLE books (
      BookId INTEGER PRIMARY KEY,
      Title TEXT NOT NULL,
      AuthorId INTEGER NOT NULL REFERENCES authors(AuthorId),
      PublisherId INTEGER REFERENCES publishers(PublisherId),
      GenreId INTEGER REFERENCES genres(GenreId),
      PublishedYear INTEGER,
      Pages INTEGER NOT NULL,
      Price REAL NOT NULL
    );

    CREATE TABLE customers (
      CustomerId INTEGER PRIMARY KEY,
      FirstName TEXT NOT NULL,
      LastName TEXT NOT NULL,
      Email TEXT NOT NULL,
      City TEXT,
      Country TEXT
    );

    CREATE TABLE orders (
      OrderId INTEGER PRIMARY KEY,
      CustomerId INTEGER NOT NULL REFERENCES customers(CustomerId),
      OrderDate TEXT NOT NULL,
      Total REAL NOT NULL
    );

    CREATE TABLE order_items (
      OrderItemId INTEGER PRIMARY KEY,
      OrderId INTEGER NOT NULL REFERENCES orders(OrderId),
      BookId INTEGER NOT NULL REFERENCES books(BookId),
      UnitPrice REAL NOT NULL,
      Quantity INTEGER NOT NULL
    );

    CREATE TABLE reading_lists (
      ReadingListId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL
    );

    CREATE TABLE reading_list_books (
      ReadingListId INTEGER NOT NULL REFERENCES reading_lists(ReadingListId),
      BookId INTEGER NOT NULL REFERENCES books(BookId),
      PRIMARY KEY (ReadingListId, BookId)
    );
  ''');

  _insert(db, 'authors', _authors);
  _insert(db, 'publishers', _publishers);
  _insert(db, 'genres', _genres);
  _insert(db, 'books', _books);
  _insert(db, 'customers', _customers);
  _insert(db, 'orders', _orders);
  _insert(db, 'order_items', _orderItems);
  _insert(db, 'reading_lists', _readingLists);
  _insert(db, 'reading_list_books', _readingListBooks);

  return db;
}

void _insert(Database db, String table, List<List<Object>> rows) {
  final placeholders = List.filled(rows.first.length, '?').join(', ');
  final stmt = db.prepare('INSERT INTO $table VALUES ($placeholders)');
  for (final row in rows) {
    stmt.execute(row);
  }
  stmt.close();
}

const _authors = [
  [1, 'Jane Austen', 'England'],
  [2, 'Charles Dickens', 'England'],
  [3, 'Mark Twain', 'United States'],
  [4, 'Agatha Christie', 'England'],
  [5, 'Arthur Conan Doyle', 'Scotland'],
  [6, 'Jules Verne', 'France'],
  [7, 'H. G. Wells', 'England'],
  [8, 'Louisa May Alcott', 'United States'],
  [9, 'L. M. Montgomery', 'Canada'],
  [10, 'Robert Louis Stevenson', 'Scotland'],
  [11, 'Chinua Achebe', 'Nigeria'],
  [12, 'Harper Lee', 'United States'],
  [13, 'Dava Sobel', 'United States'],
  [14, 'David McCullough', 'United States'],
  [15, 'Laura Ingalls Wilder', 'United States'],
];

const _publishers = [
  [1, 'Harbor Press', 'London'],
  [2, 'Northwind Books', 'Edinburgh'],
  [3, 'Blue Lantern', 'Boston'],
  [4, 'Oakleaf Publishing', 'Toronto'],
  [5, 'Summit House', 'New York'],
];

const _genres = [
  [1, 'Classics'],
  [2, 'Mystery'],
  [3, 'Science Fiction'],
  [4, 'Adventure'],
  [5, "Children's"],
  [6, 'History'],
  [7, 'Biography'],
];

// BookId, Title, AuthorId, PublisherId, GenreId, PublishedYear, Pages, Price
const _books = [
  [1, 'Pride and Prejudice', 1, 1, 1, 1813, 432, 9.99],
  [2, 'Emma', 1, 1, 1, 1815, 474, 9.99],
  [3, 'Sense and Sensibility', 1, 1, 1, 1811, 409, 8.99],
  [4, 'Persuasion', 1, 2, 1, 1817, 249, 7.99],
  [5, 'Great Expectations', 2, 2, 1, 1861, 505, 10.99],
  [6, 'Oliver Twist', 2, 2, 1, 1838, 554, 9.99],
  [7, 'A Tale of Two Cities', 2, 1, 1, 1859, 489, 10.99],
  [8, 'David Copperfield', 2, 3, 1, 1850, 882, 12.99],
  [9, 'The Adventures of Tom Sawyer', 3, 3, 4, 1876, 274, 7.99],
  [10, 'Adventures of Huckleberry Finn', 3, 3, 1, 1884, 366, 8.99],
  [11, 'Little Women', 8, 4, 1, 1868, 759, 11.99],
  [12, 'Things Fall Apart', 11, 5, 1, 1958, 209, 12.99],
  [13, 'To Kill a Mockingbird', 12, 5, 1, 1960, 336, 14.99],
  [14, 'The Murder of Roger Ackroyd', 4, 2, 2, 1926, 312, 11.99],
  [15, 'Murder on the Orient Express', 4, 2, 2, 1934, 256, 11.99],
  [16, 'The A.B.C. Murders', 4, 4, 2, 1936, 256, 10.99],
  [17, 'The Hound of the Baskervilles', 5, 1, 2, 1902, 256, 8.99],
  [18, 'A Study in Scarlet', 5, 1, 2, 1887, 188, 7.99],
  [19, 'The Sign of the Four', 5, 4, 2, 1890, 166, 7.99],
  [20, 'Twenty Thousand Leagues Under the Seas', 6, 3, 3, 1870, 426, 9.99],
  [21, 'Journey to the Center of the Earth', 6, 3, 3, 1864, 240, 8.99],
  [22, 'The Time Machine', 7, 4, 3, 1895, 118, 6.99],
  [23, 'The War of the Worlds', 7, 4, 3, 1898, 192, 7.99],
  [24, 'The First Men in the Moon', 7, 5, 3, 1901, 240, 7.99],
  [25, 'Around the World in Eighty Days', 6, 3, 4, 1872, 252, 8.99],
  [26, 'Treasure Island', 10, 1, 4, 1883, 292, 7.99],
  [27, 'Kidnapped', 10, 2, 4, 1886, 288, 8.99],
  [28, 'The Mysterious Island', 6, 5, 4, 1875, 640, 11.99],
  [29, 'Anne of Green Gables', 9, 4, 5, 1908, 320, 8.99],
  [30, 'Anne of Avonlea', 9, 4, 5, 1909, 304, 8.99],
  [31, 'Little House in the Big Woods', 15, 5, 5, 1932, 238, 7.99],
  [32, 'Little House on the Prairie', 15, 5, 5, 1935, 335, 7.99],
  [33, 'Little Men', 8, 4, 5, 1871, 376, 9.99],
  [34, 'Longitude', 13, 1, 6, 1995, 184, 13.99],
  [35, '1776', 14, 2, 6, 2005, 386, 16.99],
  [36, 'The Wright Brothers', 14, 2, 6, 2015, 336, 15.99],
  [37, 'John Adams', 14, 3, 7, 2001, 751, 18.99],
  [38, 'Truman', 14, 3, 7, 1992, 1117, 19.99],
  [39, "Galileo's Daughter", 13, 1, 7, 1999, 420, 15.99],
];

const _customers = [
  [1, 'Amara', 'Okafor', 'amara.okafor@example.com', 'Lagos', 'Nigeria'],
  [2, 'Daniel', 'Weber', 'daniel.weber@example.com', 'Berlin', 'Germany'],
  [3, 'Sofia', 'Rossi', 'sofia.rossi@example.com', 'Rome', 'Italy'],
  [4, 'James', 'Carter', 'james.carter@example.com', 'Chicago', 'USA'],
  [5, 'Priya', 'Nair', 'priya.nair@example.com', 'Mumbai', 'India'],
  [6, 'Lucas', 'Silva', 'lucas.silva@example.com', 'São Paulo', 'Brazil'],
  [7, 'Emma', 'Johansson', 'emma.johansson@example.com', 'Stockholm', 'Sweden'],
  [8, 'Kenji', 'Tanaka', 'kenji.tanaka@example.com', 'Osaka', 'Japan'],
  [9, 'Fatima', 'Hassan', 'fatima.hassan@example.com', 'Cairo', 'Egypt'],
  [10, 'Olivia', 'Brown', 'olivia.brown@example.com', 'Toronto', 'Canada'],
];

// Each Total is the sum of its order_items (UnitPrice * Quantity).
const _orders = [
  [1, 3, '2024-01-12', 34.97],
  [2, 3, '2024-03-05', 48.97],
  [3, 3, '2024-06-18', 29.98],
  [4, 1, '2024-01-20', 27.98],
  [5, 1, '2024-05-02', 16.98],
  [6, 2, '2024-02-14', 16.98],
  [7, 2, '2024-07-09', 8.99],
  [8, 4, '2024-02-28', 34.97],
  [9, 5, '2024-03-17', 15.98],
  [10, 6, '2024-04-03', 16.98],
  [11, 7, '2024-04-22', 21.98],
  [12, 8, '2024-05-30', 17.98],
  [13, 9, '2024-08-11', 15.99],
  [14, 10, '2024-09-01', 16.98],
  [15, 4, '2024-10-15', 15.99],
];

// OrderItemId, OrderId, BookId, UnitPrice, Quantity
const _orderItems = [
  [1, 1, 1, 9.99, 1],
  [2, 1, 5, 10.99, 1],
  [3, 1, 34, 13.99, 1],
  [4, 2, 1, 9.99, 1],
  [5, 2, 37, 18.99, 1],
  [6, 2, 38, 19.99, 1],
  [7, 3, 35, 16.99, 1],
  [8, 3, 12, 12.99, 1],
  [9, 4, 12, 12.99, 1],
  [10, 4, 13, 14.99, 1],
  [11, 5, 29, 8.99, 1],
  [12, 5, 31, 7.99, 1],
  [13, 6, 20, 9.99, 1],
  [14, 6, 22, 6.99, 1],
  [15, 7, 17, 8.99, 1],
  [16, 8, 14, 11.99, 1],
  [17, 8, 15, 11.99, 1],
  [18, 8, 16, 10.99, 1],
  [19, 9, 26, 7.99, 2],
  [20, 10, 9, 7.99, 1],
  [21, 10, 10, 8.99, 1],
  [22, 11, 11, 11.99, 1],
  [23, 11, 33, 9.99, 1],
  [24, 12, 25, 8.99, 1],
  [25, 12, 21, 8.99, 1],
  [26, 13, 39, 15.99, 1],
  [27, 14, 32, 7.99, 1],
  [28, 14, 30, 8.99, 1],
  [29, 15, 36, 15.99, 1],
];

const _readingLists = [
  [1, 'Summer Reading'],
  [2, 'Classic Mysteries'],
  [3, 'Book Club Picks'],
];

const _readingListBooks = [
  [1, 9],
  [1, 22],
  [1, 25],
  [1, 26],
  [1, 29],
  [2, 14],
  [2, 15],
  [2, 17],
  [2, 18],
  [3, 1],
  [3, 11],
  [3, 12],
  [3, 13],
  [3, 34],
  [3, 36],
];
