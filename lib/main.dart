import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:async/async.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:simple_permissions/simple_permissions.dart';

void main() {
  runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Donations',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: MyHomePage(title: 'Donations'),
      )
  );
}

class DonItem {
  final String id;
  final String name;
  final String address;
  final String email;
  final String phone;
  final String amount;
  final String date;

  DonItem({this.id, this.name,this.address,this.email,this.phone,this.amount,this.date});

  DonItem.fromJsonMap(Map<String, dynamic> map)
      : id = map['id'],
        name = map['name'],
        address = map['address'],
        email = map['email'],
        phone = map['phone'],
        amount = map['amount'],
        date = map['date'];

  Map<String, dynamic> toJsonMap() => {
    'id': id,
    'name': name,
    'address':address,
    'email':email,
    'phone':phone,
    'amount':amount,
    'date': date,
  };
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  bool _allowWriteFile = false;
  int _cind = 0;
  String names="";
  String addre="";
  String emailadd="";
  String phonef="";
  String amountf="";
  static const kDbFileName = 'dondata.db';
  static const kDbTableName = 'donations';
  final AsyncMemoizer _memoizer = AsyncMemoizer();

  Database _db;
  List<DonItem> _donations = [];

  @override
  void initState() {
    super.initState();
    _requestWritePermission();
  }

  _requestWritePermission() async {
    PermissionStatus permissionStatus = await SimplePermissions.requestPermission(Permission.WriteExternalStorage);

    if (permissionStatus == PermissionStatus.authorized) {
      setState(() {
        _allowWriteFile = true;
      });
    }
  }


  Future<void> _initDb() async {
    final dbFolder = await getDatabasesPath();
    if (!await Directory(dbFolder).exists()) {
      await Directory(dbFolder).create(recursive: true);
    }
    final dbPath = join(dbFolder, kDbFileName);
    this._db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
        CREATE TABLE $kDbTableName(
          id TEXT PRIMARY KEY, 
          name TEXT,
          address TEXT,
          email TEXT,
          phone TEXT,
          amount TEXT,
          date TEXT)
        ''');
      },
    );
  }

  Future<void> _getDonItems() async {
    List<Map> jsons = await this._db.rawQuery('SELECT * FROM $kDbTableName');
    print('${jsons.length} rows retrieved from db!');
    this._donations = jsons.map((json) => DonItem.fromJsonMap(json)).toList();
  }

  Future<void> _addDonItem(DonItem di) async {
    await this._db.transaction(
          (Transaction txn) async {
        int id = await txn.rawInsert('''
          INSERT INTO $kDbTableName
            (id, name, address, email, phone, amount, date)
          VALUES
            (
              "${di.id}",
              "${di.name}", 
              "${di.address}",
              "${di.email}",
              "${di.phone}",
              "${di.amount}",
              "${di.date}"
            )''');
        print('Inserted todo item with id=$id.');
      },
    );
  }

  Future<bool> _asyncInit() async {
    await _memoizer.runOnce(() async {
      await _initDb();
      await _getDonItems();
    });
    return true;
  }

  Future<void> _updateUI() async {
    await _getDonItems();
    setState(() {
      names="";
      addre="";
      emailadd="";
      phonef="";
      amountf="";
    });
  }

  Future get _localPath async {

    final externalDirectory = await getExternalStorageDirectory();

    return externalDirectory.path;
  }

  Future get _localFile async {
    final path = await _localPath;

    DateTime now = DateTime.now();
    String dte = DateFormat('yyyy-MM-dd').format(now);
    String fname = dte +'-'+ DateFormat('kkmmss').format(now);
    String fs = '$path/$fname.csv';
    print(fs);
    return File(fs);
  }

  Future getCv() async{
    List<DonItem> dond =_donations;
    List<List<String>> csvData = [
      <String>['ID', 'Name', 'Address','Email','Phone','Amount','Date'],
      ...dond.map((item) => [item.id, item.name, item.address,item.email,item.phone,item.amount,item.date]),
    ];

    String csvf = const  ListToCsvConverter().convert(csvData);

    if (!_allowWriteFile) {
      return null;
    }

    final File file = await _localFile;

    String filep = file.path;

    File result= await file.writeAsString(csvf);

    if (result == null ) {
      print("Writing to file failed");
    } else {
      print("Successfully writing to file");
      showInSnackBar('the file is saved $filep');

    }

  }

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  void showInSnackBar(String value) {
    _scaffoldKey.currentState.showSnackBar(new SnackBar(content: new Text(value)));
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton(
            onSelected: (x){
              if(x=='exp'){
                getCv();
              }
            },
            itemBuilder: (BuildContext ctx){
              return [
                PopupMenuItem(
                  child: Text("Export"),
                  value: 'exp',
                )
              ];
            },
          )
        ],
      ),
      body: FutureBuilder<bool>(
        future: _asyncInit(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data == false)
            return Center(
              child: CircularProgressIndicator(),
            );
          return Scaffold(
            body: ListView(
              children: this._donations.map((DonItem dil){
                return ListTile(
                    title: Text(
                      dil.name,
                    ),
                    subtitle: Text('id=${dil.id}\ncreated at ${dil.date}'),
                    isThreeLine: true,
                    onTap: (){
                      showModalBottomSheet(context: context,
                          builder:(BuildContext context){
                              return Expanded(
                                child: ListView(
                                  children: [
                                    ListTile(
                                      title: Text(dil.id) ,
                                      subtitle: Text("ID"),
                                    ),
                                    ListTile(
                                      title: Text(dil.name) ,
                                      subtitle: Text("Name"),
                                    ),
                                    ListTile(
                                      title: Text(dil.address) ,
                                      subtitle: Text("Address"),
                                    ),
                                    ListTile(
                                      title: Text(dil.email) ,
                                      subtitle: Text("Email Address"),
                                    ),
                                    ListTile(
                                      title: Text(dil.phone) ,
                                      subtitle: Text("Phone"),
                                    ),
                                    ListTile(
                                      title: Text(dil.amount) ,
                                      subtitle: Text("Amount"),
                                    ),
                                    ListTile(
                                      title: Text(dil.date) ,
                                      subtitle: Text("Date & Time"),
                                    ),
                                  ],
                                ),
                              );
                          }
                      );
                    },
                    trailing: Text(dil.amount)
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          AlertDialog al = AlertDialog(
            title: Text("Add Donation"),
            content:Container(
              width: double.maxFinite,
              child: Wrap(
                children: <Widget>[
                  ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      TextField(
                        decoration: InputDecoration.collapsed(hintText: "Name"),
                        onChanged: (a){
                          names=a;
                          print(a);
                        },
                      ),
                      Divider(thickness: 1,),
                      TextField(
                        decoration: InputDecoration.collapsed(hintText: "Address"),
                        onChanged: (a){
                          addre=a;
                          print(a);
                        },
                      ),
                      Divider(thickness: 1,),
                      TextField(
                        decoration: InputDecoration.collapsed(hintText: "Email"),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (a){
                          emailadd=a;
                          print(a);
                        },
                      ),
                      Divider(thickness: 1,),
                      TextField(
                        decoration: InputDecoration.collapsed(hintText: "Phone No"),
                        keyboardType: TextInputType.phone,
                        onChanged: (a){
                          phonef=a;
                          print(a);
                        },
                      ),
                      Divider(thickness: 1,),
                      TextField(
                        decoration: InputDecoration.collapsed(hintText: "Amount"),
                        keyboardType: TextInputType.number,
                        onChanged: (a){
                          amountf=a;
                          print(a);
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text("Cancel"),
                onPressed:(){
                  Navigator.pop(context);
                },
              ),
              FlatButton(
                child: Text("Add"),
                onPressed:()  async {
                  if(names != "" && addre != "" && emailadd != "" && phonef != "" && amountf != ""){
                    String idvar = await Uuid().v4();
                    DateTime now = DateTime.now();
                    String dt = DateTime.now().toString();
                    String formattedDate = DateFormat('kkmmss').format(now);
                    await _addDonItem(
                        DonItem(
                            id: idvar.substring(0,8)+formattedDate,
                            name: names,
                            address: addre,
                            email: emailadd,
                            phone: phonef,
                            amount: amountf,
                            date: dt
                        )
                    );
                    _updateUI();
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context);
                    showInSnackBar("Enter all the details");
                  }
                },
              )
            ],
          );
          showDialog(
              context: context,
              builder: (BuildContext  context){
                return al;
            }
          );
        },
        tooltip: 'Add Donation',
        child: Icon(Icons.add),
      ),
    );
  }
}


