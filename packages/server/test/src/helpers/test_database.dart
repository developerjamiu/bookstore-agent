import 'package:sqlite3/sqlite3.dart';

Database createSeedDatabase({String? path}) {
  final db = path != null ? sqlite3.open(path) : sqlite3.openInMemory();

  db.execute('''
    CREATE TABLE artists (
      ArtistId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL
    );

    CREATE TABLE albums (
      AlbumId INTEGER PRIMARY KEY,
      Title TEXT NOT NULL,
      ArtistId INTEGER NOT NULL REFERENCES artists(ArtistId)
    );

    CREATE TABLE genres (
      GenreId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL
    );

    CREATE TABLE tracks (
      TrackId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL,
      AlbumId INTEGER REFERENCES albums(AlbumId),
      GenreId INTEGER REFERENCES genres(GenreId),
      Composer TEXT,
      Milliseconds INTEGER NOT NULL,
      Bytes INTEGER,
      UnitPrice REAL NOT NULL
    );

    CREATE TABLE customers (
      CustomerId INTEGER PRIMARY KEY,
      FirstName TEXT NOT NULL,
      LastName TEXT NOT NULL,
      Email TEXT NOT NULL,
      City TEXT,
      Country TEXT
    );

    CREATE TABLE invoices (
      InvoiceId INTEGER PRIMARY KEY,
      CustomerId INTEGER NOT NULL REFERENCES customers(CustomerId),
      InvoiceDate TEXT NOT NULL,
      Total REAL NOT NULL
    );

    CREATE TABLE invoice_lines (
      InvoiceLineId INTEGER PRIMARY KEY,
      InvoiceId INTEGER NOT NULL REFERENCES invoices(InvoiceId),
      TrackId INTEGER NOT NULL REFERENCES tracks(TrackId),
      UnitPrice REAL NOT NULL,
      Quantity INTEGER NOT NULL
    );

    CREATE TABLE playlists (
      PlaylistId INTEGER PRIMARY KEY,
      Name TEXT NOT NULL
    );

    CREATE TABLE playlist_tracks (
      PlaylistId INTEGER NOT NULL REFERENCES playlists(PlaylistId),
      TrackId INTEGER NOT NULL REFERENCES tracks(TrackId),
      PRIMARY KEY (PlaylistId, TrackId)
    );
  ''');

  _seedArtists(db);
  _seedGenres(db);
  _seedAlbums(db);
  _seedTracks(db);
  _seedCustomers(db);
  _seedInvoices(db);
  _seedPlaylists(db);

  return db;
}

void _seedArtists(Database db) {
  const artists = [
    [1, 'AC/DC'],
    [2, 'Led Zeppelin'],
    [3, 'Metallica'],
    [4, 'U2'],
    [5, 'Queen'],
    [6, 'Pink Floyd'],
    [7, 'The Beatles'],
    [8, 'Nirvana'],
    [9, 'Miles Davis'],
    [10, 'John Coltrane'],
    [11, 'Bob Marley'],
    [12, 'Adele'],
    [13, 'Radiohead'],
    [14, 'Daft Punk'],
    [15, 'Amy Winehouse'],
  ];
  final stmt = db.prepare('INSERT INTO artists VALUES (?, ?)');
  for (final a in artists) {
    stmt.execute(a);
  }
  stmt.close();
}

void _seedGenres(Database db) {
  const genres = [
    [1, 'Rock'],
    [2, 'Jazz'],
    [3, 'Metal'],
    [4, 'Pop'],
    [5, 'Reggae'],
    [6, 'Electronic'],
    [7, 'Blues'],
  ];
  final stmt = db.prepare('INSERT INTO genres VALUES (?, ?)');
  for (final g in genres) {
    stmt.execute(g);
  }
  stmt.close();
}

void _seedAlbums(Database db) {
  const albums = [
    [1, 'Back in Black', 1],
    [2, 'Led Zeppelin IV', 2],
    [3, 'Master of Puppets', 3],
    [4, 'The Joshua Tree', 4],
    [5, 'A Night at the Opera', 5],
    [6, 'The Dark Side of the Moon', 6],
    [7, 'Abbey Road', 7],
    [8, 'Nevermind', 8],
    [9, 'Kind of Blue', 9],
    [10, 'A Love Supreme', 10],
    [11, 'Legend', 11],
    [12, '21', 12],
    [13, 'OK Computer', 13],
    [14, 'Random Access Memories', 14],
    [15, 'Back to Black', 15],
    [16, 'Highway to Hell', 1],
    [17, 'Physical Graffiti', 2],
    [18, 'Ride the Lightning', 3],
    [19, 'Achtung Baby', 4],
    [20, 'News of the World', 5],
  ];
  final stmt = db.prepare('INSERT INTO albums VALUES (?, ?, ?)');
  for (final a in albums) {
    stmt.execute(a);
  }
  stmt.close();
}

void _seedTracks(Database db) {
  const tracks = [
    [1, 'Hells Bells', 1, 1, 'Angus Young', 312000, 5100000, 0.99],
    [2, 'Back in Black', 1, 1, 'Angus Young', 255000, 4200000, 0.99],
    [
      3,
      'You Shook Me All Night Long',
      1,
      1,
      'Angus Young',
      210000,
      3400000,
      0.99,
    ],
    [4, 'Shoot to Thrill', 1, 1, 'Angus Young', 257000, 4200000, 0.99],
    [5, 'Stairway to Heaven', 2, 1, 'Jimmy Page', 482000, 7900000, 0.99],
    [6, 'Black Dog', 2, 1, 'Jimmy Page', 296000, 4800000, 0.99],
    [7, 'Rock and Roll', 2, 1, 'Jimmy Page', 220000, 3600000, 0.99],
    [8, 'Master of Puppets', 3, 3, 'James Hetfield', 516000, 8400000, 0.99],
    [9, 'Battery', 3, 3, 'James Hetfield', 312000, 5100000, 0.99],
    [
      10,
      'Welcome to the Jungle',
      3,
      3,
      'James Hetfield',
      275000,
      4500000,
      0.99,
    ],
    [11, 'Where the Streets Have No Name', 4, 1, 'U2', 336000, 5500000, 0.99],
    [12, 'With or Without You', 4, 1, 'U2', 296000, 4800000, 0.99],
    [
      13,
      'I Still Haven\'t Found What I\'m Looking For',
      4,
      1,
      'U2',
      281000,
      4600000,
      0.99,
    ],
    [14, 'Bohemian Rhapsody', 5, 1, 'Freddie Mercury', 354000, 5800000, 0.99],
    [15, 'You\'re My Best Friend', 5, 4, 'John Deacon', 172000, 2800000, 0.99],
    [16, 'Money', 6, 1, 'Roger Waters', 382000, 6200000, 0.99],
    [17, 'Time', 6, 1, 'David Gilmour', 413000, 6700000, 0.99],
    [18, 'Comfortably Numb', 6, 1, 'David Gilmour', 382000, 6200000, 0.99],
    [19, 'Come Together', 7, 1, 'John Lennon', 259000, 4200000, 0.99],
    [20, 'Here Comes the Sun', 7, 1, 'George Harrison', 185000, 3000000, 0.99],
    [21, 'Something', 7, 1, 'George Harrison', 182000, 3000000, 0.99],
    [22, 'Smells Like Teen Spirit', 8, 1, 'Kurt Cobain', 301000, 4900000, 0.99],
    [23, 'Come as You Are', 8, 1, 'Kurt Cobain', 219000, 3600000, 0.99],
    [24, 'Lithium', 8, 1, 'Kurt Cobain', 253000, 4100000, 0.99],
    [25, 'So What', 9, 2, 'Miles Davis', 562000, 9200000, 0.99],
    [26, 'Blue in Green', 9, 2, 'Miles Davis', 328000, 5400000, 0.99],
    [27, 'Freddie Freeloader', 9, 2, 'Miles Davis', 590000, 9600000, 0.99],
    [28, 'A Love Supreme Pt. 1', 10, 2, 'John Coltrane', 462000, 7500000, 0.99],
    [29, 'A Love Supreme Pt. 2', 10, 2, 'John Coltrane', 425000, 6900000, 0.99],
    [30, 'No Woman No Cry', 11, 5, 'Bob Marley', 285000, 4600000, 0.99],
    [31, 'Could You Be Loved', 11, 5, 'Bob Marley', 236000, 3900000, 0.99],
    [32, 'Jamming', 11, 5, 'Bob Marley', 213000, 3500000, 0.99],
    [33, 'Rolling in the Deep', 12, 4, 'Adele', 228000, 3700000, 1.29],
    [34, 'Someone Like You', 12, 4, 'Adele', 285000, 4600000, 1.29],
    [35, 'Set Fire to the Rain', 12, 4, 'Adele', 242000, 3900000, 1.29],
    [36, 'Paranoid Android', 13, 1, 'Thom Yorke', 383000, 6200000, 0.99],
    [37, 'Karma Police', 13, 1, 'Thom Yorke', 263000, 4300000, 0.99],
    [38, 'No Surprises', 13, 1, 'Thom Yorke', 229000, 3700000, 0.99],
    [39, 'Get Lucky', 14, 6, 'Pharrell Williams', 369000, 6000000, 1.29],
    [40, 'Instant Crush', 14, 6, 'Daft Punk', 337000, 5500000, 1.29],
    [41, 'Rehab', 15, 4, 'Amy Winehouse', 213000, 3500000, 1.29],
    [42, 'Back to Black', 15, 4, 'Amy Winehouse', 240000, 3900000, 1.29],
    [43, 'Highway to Hell', 16, 1, 'Angus Young', 208000, 3400000, 0.99],
    [44, 'Touch Too Much', 16, 1, 'Angus Young', 257000, 4200000, 0.99],
    [45, 'Kashmir', 17, 1, 'Jimmy Page', 508000, 8300000, 0.99],
    [46, 'Houses of the Holy', 17, 1, 'Jimmy Page', 242000, 3900000, 0.99],
    [47, 'Ride the Lightning', 18, 3, 'James Hetfield', 397000, 6500000, 0.99],
    [48, 'Fade to Black', 18, 3, 'James Hetfield', 416000, 6800000, 0.99],
    [49, 'One', 19, 1, 'U2', 276000, 4500000, 0.99],
    [50, 'Mysterious Ways', 19, 1, 'U2', 244000, 4000000, 0.99],
    [51, 'We Will Rock You', 20, 1, 'Brian May', 122000, 2000000, 0.99],
    [
      52,
      'We Are the Champions',
      20,
      1,
      'Freddie Mercury',
      181000,
      2900000,
      0.99,
    ],
  ];
  final stmt = db.prepare('INSERT INTO tracks VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
  for (final t in tracks) {
    stmt.execute(t);
  }
  stmt.close();
}

void _seedCustomers(Database db) {
  const customers = [
    [1, 'Luís', 'Gonçalves', 'luisg@embraer.com.br', 'São Paulo', 'Brazil'],
    [2, 'Leonie', 'Köhler', 'leoniekohler@surfeu.de', 'Stuttgart', 'Germany'],
    [3, 'François', 'Tremblay', 'ftremblay@gmail.com', 'Montréal', 'Canada'],
    [4, 'Bjørn', 'Hansen', 'bjorn.hansen@yahoo.no', 'Oslo', 'Norway'],
    [5, 'Helena', 'Holý', 'hholy@gmail.com', 'Prague', 'Czech Republic'],
    [6, 'Astrid', 'Gruber', 'astrid.gruber@apple.at', 'Vienna', 'Austria'],
    [7, 'Daan', 'Peeters', 'daan_peeters@apple.be', 'Brussels', 'Belgium'],
    [8, 'Kara', 'Nielsen', 'kara.nielsen@jubii.dk', 'Copenhagen', 'Denmark'],
    [9, 'Camille', 'Bernard', 'camille.bernard@yahoo.fr', 'Paris', 'France'],
    [10, 'John', 'Smith', 'johnsmith@gmail.com', 'New York', 'USA'],
  ];
  final stmt = db.prepare('INSERT INTO customers VALUES (?, ?, ?, ?, ?, ?)');
  for (final c in customers) {
    stmt.execute(c);
  }
  stmt.close();
}

void _seedInvoices(Database db) {
  const invoices = [
    [1, 1, '2024-01-15', 5.94],
    [2, 1, '2024-04-20', 3.96],
    [3, 2, '2024-02-10', 8.91],
    [4, 3, '2024-03-05', 1.98],
    [5, 4, '2024-01-25', 13.86],
    [6, 5, '2024-05-12', 2.97],
    [7, 6, '2024-03-18', 5.94],
    [8, 7, '2024-06-01', 1.98],
    [9, 8, '2024-04-10', 3.96],
    [10, 9, '2024-02-28', 7.92],
    [11, 10, '2024-05-20', 9.90],
    [12, 10, '2024-07-15', 3.96],
    [13, 3, '2024-08-01', 5.94],
    [14, 5, '2024-09-10', 7.92],
    [15, 1, '2024-10-05', 11.88],
  ];
  final stmt = db.prepare('INSERT INTO invoices VALUES (?, ?, ?, ?)');
  for (final i in invoices) {
    stmt.execute(i);
  }
  stmt.close();

  const invoiceLines = [
    [1, 1, 1, 0.99, 1],
    [2, 1, 5, 0.99, 1],
    [3, 1, 14, 0.99, 1],
    [4, 1, 22, 0.99, 1],
    [5, 1, 33, 1.29, 1],
    [6, 1, 39, 1.29, 1],
    [7, 2, 19, 0.99, 1],
    [8, 2, 20, 0.99, 1],
    [9, 2, 21, 0.99, 1],
    [10, 2, 41, 0.99, 1],
    [11, 3, 8, 0.99, 1],
    [12, 3, 9, 0.99, 1],
    [13, 3, 25, 0.99, 1],
    [14, 3, 26, 0.99, 1],
    [15, 3, 27, 0.99, 1],
    [16, 3, 36, 0.99, 1],
    [17, 3, 37, 0.99, 1],
    [18, 3, 47, 0.99, 1],
    [19, 3, 48, 0.99, 1],
    [20, 4, 30, 0.99, 1],
    [21, 4, 31, 0.99, 1],
    [22, 5, 5, 0.99, 1],
    [23, 5, 6, 0.99, 1],
    [24, 5, 7, 0.99, 1],
    [25, 5, 14, 0.99, 1],
    [26, 5, 16, 0.99, 1],
    [27, 5, 17, 0.99, 1],
    [28, 5, 18, 0.99, 1],
    [29, 5, 22, 0.99, 1],
    [30, 5, 23, 0.99, 1],
    [31, 5, 24, 0.99, 1],
    [32, 5, 43, 0.99, 1],
    [33, 5, 44, 0.99, 1],
    [34, 5, 45, 0.99, 1],
    [35, 5, 46, 0.99, 1],
    [36, 6, 33, 1.29, 1],
    [37, 6, 34, 1.29, 1],
    [38, 6, 41, 0.39, 1],
    [39, 7, 2, 0.99, 1],
    [40, 7, 3, 0.99, 1],
    [41, 7, 11, 0.99, 1],
    [42, 7, 12, 0.99, 1],
    [43, 7, 13, 0.99, 1],
    [44, 7, 49, 0.99, 1],
    [45, 8, 39, 0.99, 1],
    [46, 8, 40, 0.99, 1],
    [47, 9, 30, 0.99, 1],
    [48, 9, 31, 0.99, 1],
    [49, 9, 32, 0.99, 1],
    [50, 9, 42, 0.99, 1],
    [51, 10, 1, 0.99, 1],
    [52, 10, 2, 0.99, 1],
    [53, 10, 3, 0.99, 1],
    [54, 10, 4, 0.99, 1],
    [55, 10, 14, 0.99, 1],
    [56, 10, 22, 0.99, 1],
    [57, 10, 36, 0.99, 1],
    [58, 10, 37, 0.99, 1],
    [59, 11, 5, 0.99, 1],
    [60, 11, 8, 0.99, 1],
    [61, 11, 14, 0.99, 1],
    [62, 11, 22, 0.99, 1],
    [63, 11, 25, 0.99, 1],
    [64, 11, 33, 1.29, 1],
    [65, 11, 34, 1.29, 1],
    [66, 11, 39, 1.29, 1],
    [67, 11, 41, 1.29, 1],
    [68, 11, 51, 0.99, 1],
    [69, 12, 19, 0.99, 1],
    [70, 12, 20, 0.99, 1],
    [71, 12, 21, 0.99, 1],
    [72, 12, 43, 0.99, 1],
    [73, 13, 11, 0.99, 1],
    [74, 13, 12, 0.99, 1],
    [75, 13, 13, 0.99, 1],
    [76, 13, 25, 0.99, 1],
    [77, 13, 28, 0.99, 1],
    [78, 13, 29, 0.99, 1],
    [79, 14, 16, 0.99, 1],
    [80, 14, 17, 0.99, 1],
    [81, 14, 18, 0.99, 1],
    [82, 14, 33, 1.29, 1],
    [83, 14, 34, 1.29, 1],
    [84, 14, 35, 1.29, 1],
    [85, 14, 47, 0.99, 1],
    [86, 14, 48, 0.99, 1],
    [87, 15, 1, 0.99, 1],
    [88, 15, 2, 0.99, 1],
    [89, 15, 3, 0.99, 1],
    [90, 15, 4, 0.99, 1],
    [91, 15, 5, 0.99, 1],
    [92, 15, 8, 0.99, 1],
    [93, 15, 14, 0.99, 1],
    [94, 15, 22, 0.99, 1],
    [95, 15, 25, 0.99, 1],
    [96, 15, 30, 0.99, 1],
    [97, 15, 39, 1.29, 1],
    [98, 15, 41, 1.29, 1],
  ];
  final stmt2 = db.prepare('INSERT INTO invoice_lines VALUES (?, ?, ?, ?, ?)');
  for (final il in invoiceLines) {
    stmt2.execute(il);
  }
  stmt2.close();
}

void _seedPlaylists(Database db) {
  const playlists = [
    [1, 'Road Trip Rock'],
    [2, 'Chill Jazz'],
    [3, 'Party Anthems'],
  ];
  final stmt = db.prepare('INSERT INTO playlists VALUES (?, ?)');
  for (final p in playlists) {
    stmt.execute(p);
  }
  stmt.close();

  const playlistTracks = [
    [1, 1],
    [1, 2],
    [1, 5],
    [1, 6],
    [1, 7],
    [1, 14],
    [1, 22],
    [1, 43],
    [2, 25],
    [2, 26],
    [2, 27],
    [2, 28],
    [2, 29],
    [3, 14],
    [3, 22],
    [3, 33],
    [3, 39],
    [3, 51],
    [3, 52],
  ];
  final stmt2 = db.prepare('INSERT INTO playlist_tracks VALUES (?, ?)');
  for (final pt in playlistTracks) {
    stmt2.execute(pt);
  }
  stmt2.close();
}
