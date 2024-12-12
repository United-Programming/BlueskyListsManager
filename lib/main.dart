import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bluesky/bluesky.dart' as bskydart;
import 'package:atproto/atproto.dart' as atp;
import 'package:atproto_core/atproto_core.dart' as core;
import 'package:flutter/services.dart';
import 'package:flutter_vertical_tab_bar/flutter_vertical_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;

void main() {
  runApp(const BskyListManager());
}

class BskyListManager extends StatelessWidget {
  const BskyListManager({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluesky App to manage lists',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 12, 41, 112)),
        useMaterial3: true,
      ),
      home: const ListManagerPage(title: 'Bluesky App to manage lists'),
    );
  }
}

class ListManagerPage extends StatefulWidget {
  const ListManagerPage({super.key, required this.title});
  final String title;
  @override
  State<ListManagerPage> createState() => _ListManagerPageState();
}

class Bsky {
  final bskydart.Bluesky bsky;
  final atp.ATProto at;
  late bskydart.GraphService graph;
  late atp.RepoService repo;
  
  Bsky(this.bsky, this.at) {
    graph = bsky.graph;
    repo = at.repo;
  }
}

class BList {
  late String name;
  late String at;

  BList(String n, String a) {
    name = n;
    at = a;
  }
}

Bsky? bsky;
String loginHandle = "";
String loginAppPass = "";
List<BList> allLists = [];
List<BList> allStarterPacks = [];
Table _listsTableUserList = Table();
Table _listsTableStarterPacks = Table();
Table _listsTableUserInfo = Table();
Table _listsTableMyLists = Table();
final TextStyle boldStyle = TextStyle(fontWeight: FontWeight.bold);

String cleanHandle(String handle) {
  handle = handle.trim();
  if (handle.isEmpty) return "";
  if (handle[0] == '@') {handle = handle.substring(1);}
  else if (handle.startsWith("https://bsky.app/profile/")) {handle = handle.substring(25);}
  else if (handle.startsWith("https://")) {handle = handle.substring(8);}
  handle = handle.replaceAll(" ", "");
  if (!handle.contains('.')) return "$handle.bsky.social";
  return handle;
}

String getNow() {
  var now = DateTime.now().toIso8601String();
  return "${(now.substring(0, now.lastIndexOf('.')))}Z";
}


class _ListManagerPageState extends State<ListManagerPage> {
  @override
  Widget build(BuildContext context) {
    int tab = 0;
    return Scaffold(
      body: 
        VerticalTabs(
          tabsWidth: 120,
          indicatorWidth: 120,
          indicatorColor: Theme.of(context).colorScheme.inversePrimary,
          initialIndex: tab,
          tabs: <String>[
            "Login", 
            "Get Info",
            "Manage Lists", 
            "Users in Lists",
            "Settings"
          ], 
          contents: <Widget>[
            LoginTab(),
            GetInfoTab(),
            ManageListsTab(),
            ManageUsersInListsTab(),
            SettingsTab(),
          ])
    );
  }
}

// ************** Login ***************************************************


class LoginTab extends StatefulWidget  {
  const LoginTab({super.key});

  @override
  State<LoginTab> createState() => _LoginTabState();
}
class _LoginTabState extends State<LoginTab> {
  final TextEditingController _userHandleCtrl = TextEditingController();
  final TextEditingController _userAppPwdCtrl = TextEditingController();
  String exception = "";
  bool passwordNotVisible = true;

  @override
  Widget build(BuildContext context) {
    if (loginHandle == "" || loginAppPass == "") {
      Future.delayed(Duration.zero, () async {
        shared_prefs.SharedPreferences prefs = await shared_prefs.SharedPreferences.getInstance();
        String? handle = prefs.getString("UserHandle");
        String? apppwd = prefs.getString("UserAppPwd");
        if (context.mounted) {
          if (handle != null) _userHandleCtrl.text = handle;
          if (apppwd != null) _userAppPwdCtrl.text = apppwd;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text("Login"),
        actions: [
          Text(exception),
          IconButton(onPressed: (){ exit(0); },
            tooltip: "Shut down", icon: Icon(Icons.power_settings_new))
        ]),
      body: Center(child: Column(children: [
        Text("          Please identify yourself", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30)),
        Table(
          border: TableBorder.symmetric(),
          columnWidths: const <int, TableColumnWidth> {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth()
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(children: [
              Text("Handle:"),SizedBox(width: 20,),
              SizedBox(width: 400, height: 48, child: TextField(
                keyboardType: TextInputType.text,
                autocorrect: false,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User Handle", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.account_circle)),
                controller: _userHandleCtrl,
              )),
            ]),

            TableRow(children: [
              Tooltip(message: "An app password is a unique code that Bluesky can generate for each app that you wish to link your account to.\nTo create one go to your Settings and then Privacy and Security.\nYou will find App passwords there. Add app password, provide a name and generate the password.\nBe sure you copyu the value, you will not be able to see it again.", child: Text("App Password:")),
              SizedBox(width: 20,),
              Row(children: [
              SizedBox(width: 400, height: 48, child: TextField(
                keyboardType: TextInputType.visiblePassword,
                obscureText: passwordNotVisible,
                autocorrect: false,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "App Password", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.question_mark)),
                controller: _userAppPwdCtrl,
              )),
              IconButton(onPressed: () {
                setState(() {
                  passwordNotVisible = !passwordNotVisible;
                });
              }, icon: Icon(Icons.remove_red_eye)),
              ]),
            ]),
            TableRow(children: [Text(""), SizedBox(width: 20,), SizedBox(height: 40,)]),
            TableRow(children: [
              IconButton(onPressed: (){ getBluesky(context, false); },
              tooltip: "Re-connect to Bluesky with previous handle and password.", icon: Icon(Icons.cached)),
              SizedBox(width: 20,),
              ElevatedButton(
                child: Text("Login"),
                onPressed: () {
                  loginHandle = _userHandleCtrl.text;
                  loginAppPass = _userAppPwdCtrl.text;
                  getBluesky(context, true);
                },
              ),
            
            ]),
          ])
    ])));
  }

  void getBluesky(BuildContext context, bool refresh) async {
    Widget okButton = ElevatedButton(
      child: const Text("OK"),
      onPressed:  () {
        Navigator.of(context).pop(); // dismiss dialog
      },
    );

    try {
        final session = await atp.createSession(
          service: 'bsky.social', //! The default is `bsky.social`
          identifier: loginHandle,
          password: loginAppPass,
        );
        final bluesky = bskydart.Bluesky.fromSession(session.data);
        final at = atp.ATProto.fromSession(session.data);
        bsky = Bsky(bluesky, at);

        // Save the values for future usage
        shared_prefs.SharedPreferences prefs = await shared_prefs.SharedPreferences.getInstance();
        prefs.setString("UserHandle", loginHandle);
        prefs.setString("UserAppPwd", loginAppPass);

        if (context.mounted && refresh) {
          if (context.mounted) {
            exception = "";
            showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
              return AlertDialog(content: Text("Connected!"), actions: [ okButton ],);
            });
          }
        }
        else {
          if (context.mounted) {
            setState(() { exception = "Reconnected!"; });
            showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
              return AlertDialog(content: Text(exception), actions: [ okButton ],);
            });
          }
        }
    } on core.UnauthorizedException {
      if (context.mounted) {
        setState(() { exception = "Invalid handle or password!"; });
        showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
          return AlertDialog(content: Text(exception), actions: [ okButton ],);
        });
      }
    }
    catch (ex) {
      if (context.mounted) {
        setState(() { exception = "EXCEPTION!: $ex"; });
        showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
          return AlertDialog(content: Text(exception), actions: [ okButton ],);
        });
      }
    }
  }
}

// ************** Get Info ***************************************************

class GetInfoTab extends StatefulWidget  {
  const GetInfoTab({super.key});

  @override
  State<GetInfoTab> createState() => _GetInfoTabState();
}
class _GetInfoTabState extends State<GetInfoTab> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary, 
            actions: [
              IconButton(onPressed: (){ exit(0); },
                tooltip: "Shut down", icon: Icon(Icons.power_settings_new))
            ],
            bottom: const TabBar(
              tabs: [
                Text("Get user's lists"),
                Text("Get user's starter packs"),
                Text("Get user's info"),
                Text("Get my lists"),
              ],
            ),
            title: const Text('Get Lists'),
          ),
          body: const TabBarView(
            children: [
              GetUserListsTab(),
              GetUserStarterPacksTab(),
              GetUserInfoTab(),
              GetMyListsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

final TextEditingController _userInfoHandleCtrl = TextEditingController();

class GetUserListsTab extends StatefulWidget  {
  const GetUserListsTab({super.key});

  @override
  State<GetUserListsTab> createState() => _GetUserListsTabState();
}
class _GetUserListsTabState extends State<GetUserListsTab> {
  String progress = "";
  String exception = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
            SizedBox(height: 20,),
            Tooltip(message: "User handle can be entered in multiple ways:\n- username.bsky.social\n- @username.bsky.social\n- or just the first part <username> in case it ends with <.bsky.social>\n- DID are also valid <did:plc:4xxvirkcait46ycqabcdefgh>\n- and you can even past the HTTPS link to the profile: https://bsky.app/profile/username.bsky.social", child: 
            SizedBox(width: 600, height: 48, child: TextField(
              controller: _userInfoHandleCtrl,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User handle", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.person)),
            ))),
            SizedBox(height: 20,),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
              ElevatedButton(
                onPressed: () { getBlueskyListsForUser(); }, 
                child: const Text("Get user's lists"),
              ),
            ],),
            SizedBox(height: 20,),
            Text(progress),
            Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
            SizedBox(height: 20,),
            _listsTableUserList,
          ])),
    );
  }


  void getBlueskyListsForUser() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    String handle = cleanHandle(_userInfoHandleCtrl.text);
    if (handle == "") {
      setState(() { exception = "Invalid handle!"; });
      return;
    }
    setState(() { progress = "Collecting lists for user"; });
    try {
      final lists = await bsky!.graph.getLists(actor: handle);
      List<TableRow> rows = [];
      for (var l in lists.data.lists) {
        var uri = l.uri.toString();
        TableRow row = TableRow(children: [
          TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(l.name, textAlign: TextAlign.right,style:boldStyle)), 
          SizedBox(width: 800, height: 48, child: TextField(
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "AtUri of list", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.list)),
            controller: TextEditingController(text: uri),
          )),
        ]);
        rows.add(row);
        bool missing = true;
        for (var l in allLists) {
          if (l.at == uri) {
            missing = false;
            break;
          }
        }
        if (missing) allLists.add(BList("${l.name} ($handle)", uri));
      }
      _listsTableUserList = Table(children: rows, columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
      },);
      setState(() { exception = ""; progress = ""; });
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "User not found: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; progress = ""; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION!: $ex"; progress = ""; });
    }
  }
}

class GetUserStarterPacksTab extends StatefulWidget  {
  const GetUserStarterPacksTab({super.key});

  @override
  State<GetUserStarterPacksTab> createState() => _GetUserStarterPacksState();
}
class _GetUserStarterPacksState extends State<GetUserStarterPacksTab> {
  String progress = "";
  String exception = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
            SizedBox(height: 20,),
            Tooltip(message: "User handle can be entered in multiple ways:\n- username.bsky.social\n- @username.bsky.social\n- or just the first part <username> in case it ends with <.bsky.social>\n- DID are also valid <did:plc:4xxvirkcait46ycqabcdefgh>\n- and you can even past the HTTPS link to the profile: https://bsky.app/profile/username.bsky.social", child: 
            SizedBox(width: 600, height: 48, child: TextField(
              controller: _userInfoHandleCtrl,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User handle", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.person)),
            ))),
            SizedBox(height: 20,),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
              ElevatedButton(
                onPressed: () { getBlueskyStarterPacksListsForUser(); }, 
                child: const Text("Get user's starter packs"),
              ),
            ],),
            SizedBox(height: 20,),
            Text(progress),
            Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
            SizedBox(height: 20,),
            _listsTableStarterPacks,
          ])),
    );
  }

  void getBlueskyStarterPacksListsForUser() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    String handle = cleanHandle(_userInfoHandleCtrl.text);
    if (handle == "") {
      setState(() { exception = "Invalid handle!"; });
      return;
    }
    setState(() { progress = "Collecting starter packs for user"; exception=""; });
    try {
      final lists = await bsky!.graph.getActorStarterPacks(actor: handle);
      List<TableRow> rows = [];
      for (var l in lists.data.starterPacks) {
        var uri = l.uri.toString();
        TableRow row = TableRow(children: [
          TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(l.record.name, textAlign: TextAlign.right,style:boldStyle)), 
          SizedBox(width: 800, height: 48, child: TextField(
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "AtUri of starter pack", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.list)),
            controller: TextEditingController(text: uri),
          )),
        ]);
        rows.add(row);
        bool missing = true;
        for (var l in allStarterPacks) {
          if (l.at == uri) {
            missing = false;
            break;
          }
        }
        if (missing) allStarterPacks.add(BList(l.record.name, uri));
      }
      _listsTableStarterPacks = Table(children: rows, columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
      },);
      setState(() { exception = ""; });
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "User not found: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION!: $ex"; });
    }
  }
}

class GetUserInfoTab extends StatefulWidget  {
  const GetUserInfoTab({super.key});

  @override
  State<GetUserInfoTab> createState() => _GetUserInfoState();
}
class _GetUserInfoState extends State<GetUserInfoTab> {
  String progress = "";
  String exception = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
            SizedBox(height: 20,),
            Tooltip(message: "User handle can be entered in multiple ways:\n- username.bsky.social\n- @username.bsky.social\n- or just the first part <username> in case it ends with <.bsky.social>\n- DID are also valid <did:plc:4xxvirkcait46ycqabcdefgh>\n- and you can even past the HTTPS link to the profile: https://bsky.app/profile/username.bsky.social", child: 
            SizedBox(width: 600, height: 48, child: TextField(
              controller: _userInfoHandleCtrl,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User handle", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.person)),
            ))),
            SizedBox(height: 20,),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
              ElevatedButton(
                onPressed: () { getBlueskyInfoForUser(); }, 
                child: const Text("Get user's information"),
              ),
            ],),
            SizedBox(height: 20,),
            Text(progress),
            Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
            SizedBox(height: 20,),
            _listsTableUserInfo,
          ])),
    );
  }

  void getBlueskyInfoForUser() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    String handle = cleanHandle(_userInfoHandleCtrl.text);
    if (handle == "") {
      setState(() { exception = "Invalid handle!"; });
      return;
    }
    setState(() { progress = "Collecting info for user..."; exception=""; });
    try {
      final profile = await bsky!.bsky.actor.getProfile(actor: handle);
      final p = profile.data;
      List<TableRow> rows = [
        TableRow(children: [ Text("Name: ", textAlign: TextAlign.right,style:boldStyle),               SizedBox(width: 10), Text(p.displayName??"")]),
        TableRow(children: [ Text("Hanlde: ", textAlign: TextAlign.right,style:boldStyle),             SizedBox(width: 10), Text(p.handle)]),
        TableRow(children: [ Text("Created at: ", textAlign: TextAlign.right,style:boldStyle),         SizedBox(width: 10), Text(p.createdAt?.toIso8601String()??"")]),
        TableRow(children: [ Text("DID:", textAlign: TextAlign.right,style:boldStyle),                 SizedBox(width: 10), Text(p.did)]),
        TableRow(children: [ Text("Follows: ", textAlign: TextAlign.right,style:boldStyle),            SizedBox(width: 10), Text(p.followsCount.toString())]),
        TableRow(children: [ Text("Followers: ", textAlign: TextAlign.right,style:boldStyle),          SizedBox(width: 10), Text(p.followersCount.toString())]),
        TableRow(children: [ Text("Numbers of Posts: ", textAlign: TextAlign.right,style:boldStyle),   SizedBox(width: 10), Text(p.postsCount.toString())]),
        TableRow(children: [ Text("Description: ", textAlign: TextAlign.right,style:boldStyle),        SizedBox(width: 10), Text(p.description??"")]),
        TableRow(children: [ Text("Is Blocking: ", textAlign: TextAlign.right,style:boldStyle),        SizedBox(width: 10), Text(p.isBlocking?"Yes":"")]),
        TableRow(children: [ Text("Is Muted: ", textAlign: TextAlign.right,style:boldStyle),           SizedBox(width: 10), Text(p.isMuted?"Yes":"")]),
      ];
      setState(() { exception = ""; 
        _listsTableUserInfo = Table(children: rows,
          columnWidths: const <int, TableColumnWidth>{
            0: FixedColumnWidth(250),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        ); 
      });
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "User not found: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION!: $ex"; });
    }
  }
}


class GetMyListsTab extends StatefulWidget  {
  const GetMyListsTab({super.key});

  @override
  State<GetMyListsTab> createState() => _GetMyListsState();
}
class _GetMyListsState extends State<GetMyListsTab> {
  String progress = "";
  String exception = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
            SizedBox(height: 20,),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
              ElevatedButton(
                onPressed: () { getMyLists(); }, 
                child: const Text("Get my lists"),
              ),
            ],),
            SizedBox(height: 20,),
            Text(progress),
            Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
            SizedBox(height: 20,),
            _listsTableMyLists,
          ])),
    );
  }

  void getMyLists() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    String handle = bsky!.bsky.session!.did;
    String user = bsky!.bsky.session!.handle;
    setState(() { exception = ""; progress = "Collecting your lists..."; });
    try {
      final lists = await bsky!.graph.getLists(actor: handle);
      List<TableRow> rows = [];
      for (var l in lists.data.lists) {
        var uri = l.uri.toString();
        TableRow row = TableRow(children: [
          TableCell(verticalAlignment: TableCellVerticalAlignment.middle, child: Text(l.name, textAlign: TextAlign.right,style:boldStyle)), 
          SizedBox(width: 800, height: 48, child: TextField(
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "AtUri of list", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.list)),
            controller: TextEditingController(text: uri),
          )),
        ]);
        rows.add(row);
        bool missing = true;
        for (var l in allLists) {
          if (l.at == uri) {
            missing = false;
            break;
          }
        }
        if (missing) allLists.add(BList("${l.name} ($user)", uri));
      }
      _listsTableMyLists = Table(children: rows, columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: IntrinsicColumnWidth(),
      },);
      setState(() { exception = ""; progress = ""; });
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "User not found: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION!: $ex"; });
    }
  }
}

// ************** Manage Lists ***************************************************

class ManageListsTab extends StatefulWidget {
  const ManageListsTab({super.key});

  @override
  State<ManageListsTab> createState() => _ManageListsTabState();
}
class _ManageListsTabState extends State<ManageListsTab> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary, 
            actions: [
              IconButton(onPressed: (){ exit(0); },
                tooltip: "Shut down", icon: Icon(Icons.power_settings_new))
            ],
            bottom: const TabBar(
              tabs: [
                Text("Count"),
                Text("Copy"),
                Text("Clear"),
                Text("Copy from Starter Pack"),
              ],
            ),
            title: const Text('Get Lists'),
          ),
          body: const TabBarView(
            children: [
              CountUserInListsTab(),
              CopyOneListIntoAnotherTab(),
              CleanListTab(),
              CopyStarterPackIntoListTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class CountUserInListsTab extends StatefulWidget  {
  const CountUserInListsTab({super.key});

  @override
  State<CountUserInListsTab> createState() => _CountUserInListsTabState();
}
class _CountUserInListsTabState extends State<CountUserInListsTab> {
  String progress = "";
  String exception = "";
  String? selectedListName;
  String numberOfEntries = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,

          children: [
          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("List: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Tooltip(message: "Pick the list you wish to count\nRemember to collect the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Number of entries: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Text(numberOfEntries)
          ]),
        ]),

        SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { countNumberOfEntries(); }, 
            child: const Text("Count number of users in list"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(progress),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ])),
    );
  }

  void countNumberOfEntries() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the source list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }
    setState(() { numberOfEntries = "Counting..."; exception = ""; });
    try {
      String? cursor;
      var count = 0;
      core.AtUri uri = core.AtUri(atUri);
      while (count < maxListEntries) {
        final list = await bsky!.graph.getList(list: uri, cursor: cursor, limit: 100);
        cursor = list.data.cursor;
        count += list.data.items.length;
        setState(() { numberOfEntries = "Counting... ($count)"; });
        if (cursor == null) break;
      }
      setState(() { numberOfEntries = "$count entries"; });
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "Invalid request: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION!: $ex"; });
    }
  }
}


class CopyOneListIntoAnotherTab extends StatefulWidget  {
  const CopyOneListIntoAnotherTab({super.key});

  @override
  State<CopyOneListIntoAnotherTab> createState() => _CopyOneListIntoAnotherTabState();
}
class _CopyOneListIntoAnotherTabState extends State<CopyOneListIntoAnotherTab> {
  String progress = "";
  String exception = "";
  String? selectedSrcListName, selectedDstListName;
  bool alsoBlock = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,

          children: [
          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Source List: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Tooltip(message: "Pick the source list you wish to copy in the destination\nRemember to collect the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedSrcListName = val;
                }); 
              }, menuWidth: 800, value: selectedSrcListName,
            )),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Destination List: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Tooltip(message: "Pick the destination list to fill with the source data \nRemember to collect the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedDstListName = val;
                }); 
              }, menuWidth: 800, value: selectedDstListName,
            )),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Also block: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            TableCell(child: Align(alignment: Alignment.centerLeft, child:
            Tooltip(message: "If checked, all entries that will be copied from the source to the destination will also be blocked.", child: 
              Checkbox(value: alsoBlock,
              onChanged: (b) { 
              if (b == null) { setState(() { alsoBlock = false; }); } 
              else { setState(() { alsoBlock = b; }); }
            }, tristate: false,)))),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Progress: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Text(progress)
          ]),
        ]),

        SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { copyListIntoDestination(); }, 
            child: const Text("Begin the copy"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ])),
    );
  }

  void copyListIntoDestination() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    if (selectedSrcListName?.isEmpty??true) {
      setState(() { exception = "Select the source list!"; });
      return;
    }
    String atUriSrc = "";
    for (var l in allLists) {
      if (l.name == selectedSrcListName) {
        atUriSrc = l.at;
        break;
      }
    }
    if (atUriSrc == "") {
      setState(() { exception = "Invalid AT Uri for the source list!"; });
      return;
    }
    if (selectedDstListName?.isEmpty??true) {
      setState(() { exception = "Select the destination list!"; });
      return;
    }
    String atUriDst = "";
    for (var l in allLists) {
      if (l.name == selectedDstListName) {
        atUriDst = l.at;
        break;
      }
    }
    if (atUriDst == "") {
      setState(() { exception = "Invalid AT Uri for the destination list!"; progress = ""; });
      return;
    }
    setState(() { progress = "Copying members from source list to destination list..."; exception = ""; });
    try {
      String? cursor;
      var count = 0;
      core.NSID collId = core.NSID.parse("app.bsky.graph.listitem");
      core.AtUri uri = core.AtUri(atUriSrc);
      while (count < maxListEntries) {
        final src = await bsky!.graph.getList(list: uri, cursor: cursor);
        for(var i = 0; i < src.data.items.length; i++) {
          var usrDid = src.data.items[i].subject.did;
          var record = {
            r"$type": "app.bsky.graph.listitem",
            "subject": usrDid,
            "list": atUriDst,
            "createdAt": getNow()
          };
          var _ = await bsky!.repo.createRecord(collection: collId, record: record);
          if (alsoBlock) {
            var _ = await bsky?.graph.block(did: usrDid, createdAt: DateTime.now());
            setState(() { progress = "Merged and Blocked ${count+i}..."; });
          }
          else {
            setState(() { progress = "Merged ${count+i}..."; });
          }
        }
        count += src.data.items.length;
        setState(() { progress = "Merged $count..."; });
        cursor = src.data.cursor;
        if (cursor == null) break;
      }
      setState(() { progress = "Completed! $count merged"; });
      } on core.InvalidRequestException catch(ex) {
        var msg = ex.toString();
        int pos = msg.lastIndexOf('4');
        if (pos!=-1) {
          msg = "Invalid request: ${msg.substring(pos+3)}";
        }
        setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = ex.toString(); });
    }
  }
}

class CleanListTab extends StatefulWidget  {
  const CleanListTab({super.key});

  @override
  State<CleanListTab> createState() => _CleanListTabState();
}
class _CleanListTabState extends State<CleanListTab> {
  String progress = "";
  String exception = "";
  String? selectedListName;
  bool toBeConfirmed = false;
  bool confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,

          children: [
          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("List to clean: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Tooltip(message: "Pick the list you wish to clean\nRemember to collect the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Progress: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Text(progress)
          ]),
        ]),

        SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll<Color>(Colors.red)),
            onPressed: () {  setState(() { toBeConfirmed = true;}); }, 
            child: const Text("Begin the clean"),
          ),
        ],),

        Visibility(visible: toBeConfirmed, child: SizedBox(height: 20,)),
        Visibility(visible: toBeConfirmed, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, 
          children: [
            Text("Do you confirm you wish to delete the list: $selectedListName?"),
            ElevatedButton(
              style: const ButtonStyle(backgroundColor: WidgetStatePropertyAll<Color>(Colors.red)),
              onPressed: () { clearList(); }, 
              child: const Text("Yes, clean it up!"),
            ),
            ElevatedButton(
              onPressed: () { setState(() { toBeConfirmed = false;}); }, 
              child: const Text("Better not..."),
            ),
        ],)),

        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ])),
    );
  }

  void clearList() async {
    setState(() { toBeConfirmed = false; });
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }
    setState(() { progress = "Removing entries..."; exception = ""; });
    try {
      var count = 0;
      core.AtUri uri = core.AtUri(atUri);
      String? cursor;
      while (count < maxListEntries) {
        final list = await bsky!.graph.getList(list: uri, cursor: cursor);
        count += list.data.items.length;
        for (var element in list.data.items) {
          await bsky!.repo.deleteRecord(uri: element.uri);
        }
        setState(() { progress = "Removing... ($count)"; });
        cursor = list.data.cursor;
        if (cursor == null) break;
      }
      setState(() { progress = "Removed $count entries"; toBeConfirmed = false; });
      } on core.InvalidRequestException catch(ex) {
        var msg = ex.toString();
        int pos = msg.lastIndexOf('4');
        if (pos!=-1) {
          msg = "Invalid request: ${msg.substring(pos+3)}";
        }
        setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION!: $ex"; toBeConfirmed = false; });
    }
  }
}


class CopyStarterPackIntoListTab extends StatefulWidget  {
  const CopyStarterPackIntoListTab({super.key});

  @override
  State<CopyStarterPackIntoListTab> createState() => _CopyStarterPackIntoListTabState();
}
class _CopyStarterPackIntoListTabState extends State<CopyStarterPackIntoListTab> {
  String progress = "";
  String exception = "";
  String? selectedStarterPack, selectedDstListName;
  bool alsoBlock = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Column(children: [
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,

          children: [
          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Source List: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Tooltip(message: "Pick the Starter Pack you wish to copy in the destination list\nRemember to collect the lists and starter packs in the Get Info area.", child: 
            DropdownButton(items: allStarterPacks.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedStarterPack = val;
                }); 
              }, menuWidth: 800, value: selectedStarterPack,
            )),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Destination List: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Tooltip(message: "Pick the destination list to fill with the source data \nRemember to collect the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedDstListName = val;
                }); 
              }, menuWidth: 800, value: selectedDstListName,
            )),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Also block: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            TableCell(child: Align(alignment: Alignment.centerLeft, child:
            Tooltip(message: "If checked, all entries that will be copied from the source to the destination will also be blocked.", child: 
              Checkbox(value: alsoBlock,
              onChanged: (b) { 
              if (b == null) { setState(() { alsoBlock = false; }); } 
              else { setState(() { alsoBlock = b; }); }
            }, tristate: false,)))),
          ]),

          TableRow(children: [
            SizedBox(height: 50, child: Align(alignment: Alignment.centerRight, child: Text("Progress: ", textAlign: TextAlign.right,style:boldStyle))), SizedBox(width: 10),
            Text(progress)
          ]),
        ]),

        SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { copyFromStarterPack(); }, 
            child: const Text("Begin the copy"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ])),
    );
  }


  void copyFromStarterPack() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    if (selectedStarterPack?.isEmpty??true) {
      setState(() { exception = "Select the starter pack!"; });
      return;
    }
    String atUriSP = "";
    for (var l in allStarterPacks) {
      if (l.name == selectedStarterPack) {
        atUriSP = l.at;
        break;
      }
    }
    if (atUriSP == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }
    if (selectedDstListName?.isEmpty??true) {
      setState(() { exception = "Select the destination list!"; });
      return;
    }
    String atUriL = "";
    for (var l in allLists) {
      if (l.name == selectedDstListName) {
        atUriL = l.at;
        break;
      }
    }
    if (atUriL == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }
    setState(() { progress = "Collecting..."; exception = ""; });

    try {
      var starterPack = await bsky!.graph.getStarterPack(starterPack: core.AtUri(atUriSP));
      var spList = starterPack.data.starterPack.list;
      if (spList == null) {
        setState(() { exception = "Starter pack is empty!"; });
        return;
      }
      var uri = spList.uri;
      int count = 0;
      String? cursor;
      core.NSID collId = core.NSID.parse("app.bsky.graph.listitem");
      while (count < maxListEntries) {
        final list = await bsky!.graph.getList(list: uri, cursor: cursor, limit: 100);
        cursor = list.data.cursor;

        for(var i = 0; i < list.data.items.length; i++) {
          var usrDid = list.data.items[i].subject.did;
          var record = {
            r"$type": "app.bsky.graph.listitem",
            "subject": usrDid,
            "list": atUriL,
            "createdAt": getNow()
          };
          var _ = await bsky!.repo.createRecord(collection: collId, record: record);
          if (alsoBlock) {
            var _ = await bsky?.graph.block(did: usrDid, createdAt: DateTime.now());
            setState(() { progress = "Merged and Blocked ${count+i}..."; });
          }
          else {
            setState(() { progress = "Merged ${count+i}..."; });
          }
        }

        count += list.data.items.length;
        if (cursor == null) break;
      }

      } on core.InvalidRequestException catch(ex) {
        var msg = ex.toString();
        int pos = msg.lastIndexOf('4');
        if (pos!=-1) {
          msg = "Invalid request: ${msg.substring(pos+3)}";
        }
        setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = "EXCEPTION: $ex"; });
    }
  }
}

// ************** Users in Lists ***************************************************

class ManageUsersInListsTab extends StatefulWidget {
  const ManageUsersInListsTab({super.key});

  @override
  State<ManageUsersInListsTab> createState() => _ManageUsersInListsTabState();
}
class _ManageUsersInListsTabState extends State<ManageUsersInListsTab> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary, 
            actions: [
              IconButton(onPressed: (){ exit(0); },
                tooltip: "Shut down", icon: Icon(Icons.power_settings_new))
            ],
            bottom: const TabBar(
              tabs: [
                Text("Add user to list"),
                Text("Remove user from list"),
                Text("Check if user is in list"),
                Text("Block all users in list"),
                Text("Unlock all users in list"),
              ],
            ),
            title: const Text('Manage Users in Lists'),
          ),
          body: const TabBarView(
            children: [
              AddUserToListTab(),
              RemoveUserFromListTab(),
              CheckIfUserIsInListTab(),
              BlockAllUsersInListTab(),
              UnblockAllUsersInListTab(),
            ],
          ),
        ),
      ),
    );
  }
}

final TextEditingController _userForListHandleCtrl = TextEditingController();

class AddUserToListTab extends StatefulWidget  {
  const AddUserToListTab({super.key});

  @override
  State<AddUserToListTab> createState() => _AddUserToListTabState();
}
class _AddUserToListTabState extends State<AddUserToListTab> {
  String exception = "";
  String? selectedListName;
  String progress = "";
  bool alsoBlock = false;

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(children: [
      SizedBox(height: 20,),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
          TableRow(children: [
            Text("User(s) ID: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Write the user handle in any form you like.\nYou can also add multiple entries, one for each line.", child: 
            SizedBox(width: 600, height: 4*24, child: TextField(
              controller: _userForListHandleCtrl,
              maxLines: 32,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User handle or DID. You can add multiple ones, one per line", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.person)),
            ))),
          ]),

          TableRow(children: [
            Text("List: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Select the list where the user(s) will be added to.\nRemember to get the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            Tooltip(message: "If checked, the user(s) will also be blocked.", child: 
            Text("Also block:", textAlign: TextAlign.right,style:boldStyle)), SizedBox(width: 10),
            TableCell(child: Align(alignment: Alignment.centerLeft, child:
              Tooltip(message: "If checked, the user(s) will also be blocked.", child: 
              Checkbox(value: alsoBlock,
                onChanged: (b) { 
                  if (b == null) { setState(() { alsoBlock = false; }); } 
                  else { setState(() { alsoBlock = b; }); }
                }, tristate: false,)))),
          ]),

          TableRow(children: [
            Text("Progress: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Text(progress)
          ]),
        ],),
                SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { addUserToList(); }, 
            child: const Text("Add the user in the list"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ]));
  }

  void addUserToList() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    List<String> handles = _userForListHandleCtrl.text.split('\n');
    if (handles.isEmpty || (handles.length == 1 && handles[0].isEmpty)) {
      setState(() { exception = "Please type the handle!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }

    int numDone = 0;

    for (var handle in handles) {
      if (handle.trim().isEmpty) continue;
      var forError = handle;
      handle = cleanHandle(handle);
      if (handle == "") {
        setState(() { exception = "Invalid handle: $forError"; });
        continue;
      }

      numDone++;

      setState(() { exception = ""; progress = "Adding $handle..."; });
      try {
        var did = (await bsky!.at.identity.resolveHandle(handle: handle)).data.did;
        var now = getNow();
        var record = {
          r"$type": "app.bsky.graph.listitem",
          "subject": did,
          "list": atUri,
          "createdAt": now
        };
        var _ = await bsky!.repo.createRecord(collection: core.NSID.parse("app.bsky.graph.listitem"), record: record);

        if (alsoBlock) {
          var _ = await bsky?.graph.block(did: did, createdAt: DateTime.now());
          setState(() { progress = "$handle Added and blocked"; });
        }
        else {
          setState(() { progress = "$handle Added"; });
        }
      } on core.InvalidRequestException catch(ex) {
        var msg = ex.toString();
        int pos = msg.lastIndexOf('4');
        if (pos!=-1) {
          msg = "Invalid request: ${msg.substring(pos+3)}";
        }
        setState(() { exception = msg; });
      } catch(ex) {
        setState(() { exception = ex.toString(); });
      }
    }

    if (numDone == 0) {
      setState(() { exception = "Please type a valid handle!"; });
    }
    else if (alsoBlock) {
      setState(() { progress = "$numDone Added and blocked"; });
    }
    else {
      setState(() { progress = "$numDone Added"; });
    }
  }
}

class RemoveUserFromListTab extends StatefulWidget  {
  const RemoveUserFromListTab({super.key});

  @override
  State<RemoveUserFromListTab> createState() => _RemoveUserFromListTabState();
}
class _RemoveUserFromListTabState extends State<RemoveUserFromListTab> {
  String exception = "";
  String? selectedListName;
  String progress = "";
  bool alsoBlock = false;

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(children: [
      SizedBox(height: 20,),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
          TableRow(children: [
            Text("User(s) ID: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Write the user handle in any form you like.\nYou can also add multiple entries, one for each line.", child: 
            SizedBox(width: 600, height: 4*24, child: TextField(
              controller: _userForListHandleCtrl,
              maxLines: 32,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User handle or DID. You can add multiple ones, one per line", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.person)),
            ))),
          ]),

          TableRow(children: [
            Text("List: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Select the list where the user(s) should be removed from.\nRemember to get the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            Tooltip(message: "If checked, the user(s) will also be deblocked.", child: 
            Text("Also unblock:", textAlign: TextAlign.right,style:boldStyle)), SizedBox(width: 10),
            TableCell(child: Align(alignment: Alignment.centerLeft, child:
              Tooltip(message: "If checked, the user(s) will also be deblocked.", child: 
              Checkbox(value: alsoBlock,
                onChanged: (b) { 
                  if (b == null) { setState(() { alsoBlock = false; }); } 
                  else { setState(() { alsoBlock = b; }); }
                }, tristate: false,)))),
          ]),

          TableRow(children: [
            Text("Progress: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Text(progress)
          ]),
        ],),
                SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { removeUserFromList(); }, 
            child: const Text("Remove the user from the list"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ]));
  }

  void removeUserFromList() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    List<String> handles = _userForListHandleCtrl.text.split('\n');
    if (handles.isEmpty || (handles.length == 1 && handles[0].isEmpty)) {
      setState(() { exception = "Please type the handle!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }

    List<String> dids = [];
    List<String> didsUnblock = [];
    setState(() { progress = "Converting accounts to dids..."; });
    for (var handle in handles) {
      if (handle.trim().isEmpty) continue;
      var forError = handle;
      handle = cleanHandle(handle);
      if (handle == "") {
        setState(() { exception = "Invalid handle: $forError"; });
        continue;
      }
      var did = (await bsky!.at.identity.resolveHandle(handle: handle)).data.did;
      dids.add(did);
      didsUnblock.add(did);
    }

    try {
      core.AtUri uriList = core.AtUri(atUri);
      String? cursor;
      int count = 0;
      int numRemoved = 0;
      int total = dids.length;
      while (count < maxListEntries) {
        final list = await bsky!.graph.getList(list: uriList, cursor: cursor, limit: 100);
        cursor = list.data.cursor;
        count += list.data.items.length;
        setState(() { progress = "Removing users... (${dids.length})"; });

        for (var user in list.data.items) {
          for (var did in dids) {
            if (user.subject.did == did) {
              setState(() { progress = "Found user"; });
              var _ = await bsky!.at.repo.deleteRecord(uri: user.uri);
              dids.remove(did);
              numRemoved++;
              break;
            }
          }
          if (total == numRemoved || dids.isEmpty) {
            break;
          }
        }
        if (total == numRemoved || dids.isEmpty || cursor == null) {
          break;
        }
      }

      setState(() { exception = ""; progress = "Removed $numRemoved actors"; });

      if (alsoBlock) {
        cursor = null;
        count = 0;
        int numUnblocked = 0;
        while (count < maxListEntries) {
          var blocks = await bsky?.graph.getBlocks(cursor: cursor, limit: 100);
          if (blocks == null) break;
          setState(() { progress = "Unblocking users... (${didsUnblock.length})"; });
          cursor = blocks.data.cursor;
          count += blocks.data.blocks.length;
          for (var block in blocks.data.blocks) {
            for (var did in dids) {
              if (block.did == did) {
                setState(() { progress = "Found user"; });
                var rkey = block.viewer.blocking?.rkey;
                core.AtUri delUri = core.AtUri.make(block.handle, "app.bsky.graph.block", rkey);
                await bsky!.at.repo.deleteRecord(uri: delUri);
                await bsky?.graph.unmuteActor(actor: did);
                didsUnblock.remove(did);
                numUnblocked++;
              }
            }
            if (total == numUnblocked || didsUnblock.isEmpty) {
              break;
            }
          }
          if (total == numUnblocked || didsUnblock.isEmpty || cursor == null) {
            break;
          }
        }

        setState(() { progress = "$numRemoved Removed and $numUnblocked unblocked"; });
      }

    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "Invalid request: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = ex.toString(); });
    }
  }
}

class CheckIfUserIsInListTab extends StatefulWidget  {
  const CheckIfUserIsInListTab({super.key});

  @override
  State<CheckIfUserIsInListTab> createState() => _CheckIfUserIsInListTabState();
}
class _CheckIfUserIsInListTabState extends State<CheckIfUserIsInListTab> {
  String exception = "";
  String? selectedListName;
  String progress = "";
  bool alsoBlock = false;

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(children: [
      SizedBox(height: 20,),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
          TableRow(children: [
            Text("User(s) ID: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "User handle can be entered in multiple ways:\n- username.bsky.social\n- @username.bsky.social\n- or just the first part <username> in case it ends with <.bsky.social>\n- DID are also valid <did:plc:4xxvirkcait46ycqabcdefgh>\n- and you can even past the HTTPS link to the profile: https://bsky.app/profile/username.bsky.social", child: 
            SizedBox(width: 600, height: 48, child: TextField(
              controller: _userForListHandleCtrl,
              keyboardType: TextInputType.text,
              autocorrect: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "User handle", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.person)),
            ))),
          ]),

          TableRow(children: [
            Text("List: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Select the list to check if the user is inside.\nRemember to get the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            Text("Progress: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Text(progress)
          ]),
        ],),
                SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { checkIfUserIsInList(); }, 
            child: const Text("Check user"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ]));
  }

  void checkIfUserIsInList() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    String handle = _userForListHandleCtrl.text;
    if (handle.isEmpty) {
      setState(() { exception = "Please type the handle!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }

    var forError = handle;
    handle = cleanHandle(handle);
    if (handle == "") {
      setState(() { exception = "Invalid handle: $forError"; });
      return;
    }

    setState(() { exception = ""; progress = "Checking if $handle is in the list..."; });
    try {
      var did = (await bsky!.at.identity.resolveHandle(handle: handle)).data.did;
      core.AtUri uriList = core.AtUri(atUri);
      String? cursor;
      int count = 0;
      int pos = 0;
      while (count < maxListEntries) {
        final list = await bsky!.graph.getList(list: uriList, cursor: cursor, limit: 100);
        cursor = list.data.cursor;
        count += list.data.items.length;
        for (var user in list.data.items) {
          if (user.subject.did == did) {
            setState(() { progress = "$handle is in the list in position $pos."; });
            return;
          }
          pos++;
        }
        setState(() { exception = ""; progress = "Checking if $handle is in the list... ($count)"; });
        if (cursor == null) break;
      }

      setState(() { progress = "$handle is NOT in the list!"; });
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "Invalid request: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = ex.toString(); });
    }
  }
}

class BlockAllUsersInListTab extends StatefulWidget  {
  const BlockAllUsersInListTab({super.key});

  @override
  State<BlockAllUsersInListTab> createState() => _BlockAllUsersInListTabState();
}
class _BlockAllUsersInListTabState extends State<BlockAllUsersInListTab> {
  String exception = "";
  String? selectedListName;
  String progress = "";

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(children: [
      SizedBox(height: 20,),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [

          TableRow(children: [
            Text("List: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Select the list of people to block.\nRemember to get the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            Text("Progress: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Text(progress)
          ]),
        ],),
                SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { blockAllUsersFromTheList(); }, 
            child: const Text("Block user from the list"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ]));
  }

  void blockAllUsersFromTheList() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }

    int numDone = 0;
    setState(() { exception = ""; progress = "Blocking users in the list..."; });
    try {
      String? cursor;
      int count = 0;
      core.AtUri uriList = core.AtUri(atUri);
      while (count < maxListEntries) {
        setState(() { exception = ""; progress = "Collecting users from the list... ($count)"; });
        final list = await bsky!.graph.getList(list: uriList, cursor: cursor, limit: 100);
        cursor = list.data.cursor;
        count += list.data.items.length;
        for (var user in list.data.items) {
          var _ = await bsky?.graph.block(did: user.subject.did, createdAt: DateTime.now());
          setState(() { progress = "${user.subject.handle} blocked"; });
          numDone++;
        }
        if (cursor == null) break;
      }
    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "Invalid request: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = ex.toString(); });
    }

    if (numDone == 0) {
      setState(() { exception = "Nobody found in the list!"; });
    }
    else {
      setState(() { progress = "$numDone blocked."; });
    }
  }
}

class UnblockAllUsersInListTab extends StatefulWidget  {
  const UnblockAllUsersInListTab({super.key});

  @override
  State<UnblockAllUsersInListTab> createState() => _UnblockAllUsersInListTabState();
}
class _UnblockAllUsersInListTabState extends State<UnblockAllUsersInListTab> {
  String exception = "";
  String? selectedListName;
  String progress = "";

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(children: [
      SizedBox(height: 20,),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [

          TableRow(children: [
            Text("List: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Tooltip(message: "Select the list of people to unblock.\nRemember to get the lists in the Get Info area.", child: 
            DropdownButton(items: allLists.map((BList list) {
              return DropdownMenuItem(value: list.name, child: Text(list.name) ); }).toList(), 
              onChanged: (val) {
                setState(() {
                  selectedListName = val;
                }); 
              }, menuWidth: 800, value: selectedListName,
            )),
          ]),

          TableRow(children: [
            Text("Progress: ", textAlign: TextAlign.right,style:boldStyle), SizedBox(width: 10),
            Text(progress)
          ]),
        ],),
                SizedBox(height: 20,),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
          ElevatedButton(
            onPressed: () { unblockAllUsersFromTheList(); }, 
            child: const Text("Unblock user(s) from the list"),
          ),
        ],),
        SizedBox(height: 20,),
        Text(exception, style: TextStyle(color: Color(Colors.red.value), backgroundColor: Color(Colors.yellow.value)),),
      ]));
  }

  void unblockAllUsersFromTheList() async {
    if (bsky == null) {
      setState(() { exception = "Please login!"; });
      return;
    }
    if (selectedListName?.isEmpty??true) {
      setState(() { exception = "Select the list!"; });
      return;
    }
    String atUri = "";
    for (var l in allLists) {
      if (l.name == selectedListName) {
        atUri = l.at;
        break;
      }
    }
    if (atUri == "") {
      setState(() { exception = "Invalid AT Uri for the list!"; });
      return;
    }

    List<String> didsUnblock = [];
    List<String> dids = [];
    int numDone = 0;
    setState(() { exception = ""; progress = "Blocking users in the list..."; });
    try {
      String? cursor;
      int count = 0;
      core.AtUri uriList = core.AtUri(atUri);
      while (count < maxListEntries) {
        setState(() { exception = ""; progress = "Collecting users from the list... ($count)"; });
        final list = await bsky!.graph.getList(list: uriList, cursor: cursor, limit: 100);
        cursor = list.data.cursor;
        count += list.data.items.length;
        for (var user in list.data.items) {
          dids.add(user.subject.did);
          didsUnblock.add(user.subject.did);
          numDone++;
        }
        if (cursor == null) break;
      }

      cursor = null;
      count = 0;
      int numUnblocked = 0;
      int total = dids.length;
      while (count < maxListEntries) {
        var blocks = await bsky?.graph.getBlocks(cursor: cursor, limit: 100);
        if (blocks == null) break;
        setState(() { progress = "Unblocking users... (${didsUnblock.length})"; });
        cursor = blocks.data.cursor;
        count += blocks.data.blocks.length;
        for (var block in blocks.data.blocks) {
          for (var did in dids) {
            if (block.did == did) {
              setState(() { progress = "Found user"; });
              var rkey = block.viewer.blocking?.rkey;
              core.AtUri delUri = core.AtUri.make(block.handle, "app.bsky.graph.block", rkey);
              await bsky!.at.repo.deleteRecord(uri: delUri);
              await bsky?.graph.unmuteActor(actor: did);
              didsUnblock.remove(did);
              numUnblocked++;
            }
          }
          if (total == numUnblocked || didsUnblock.isEmpty) {
            break;
          }
        }
        if (total == numUnblocked || didsUnblock.isEmpty || cursor == null) {
          break;
        }
      }

      if (numDone == 0) {
        setState(() { exception = "Nobody found in the list!"; });
      }
      else {
        setState(() { progress = "$numDone found in the list and $numUnblocked unblocked."; });
      }

    } on core.InvalidRequestException catch(ex) {
      var msg = ex.toString();
      int pos = msg.lastIndexOf('4');
      if (pos!=-1) {
        msg = "Invalid request: ${msg.substring(pos+3)}";
      }
      setState(() { exception = msg; });
    } catch(ex) {
      setState(() { exception = ex.toString(); });
    }

  }
}

// ************** Settings ***************************************************

int maxListEntries = 25000;

class SettingsTab extends StatefulWidget  {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}
class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _maxListEntries = TextEditingController(text: "$maxListEntries");
  String exception = "";
  bool passwordNotVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text("Settings"),
        actions: [
          Text(exception),
          IconButton(onPressed: (){ exit(0); },
            tooltip: "Shut down", icon: Icon(Icons.power_settings_new))
        ]),
      body: Center(child: Column(children: [
        Table(
          border: TableBorder.symmetric(),
          columnWidths: const <int, TableColumnWidth> {
            0: IntrinsicColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth()
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(children: [
              Text("Max items from a list:"),SizedBox(width: 20,),
              Row(children: [
              SizedBox(width: 400, height: 48, child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Max list entries", hintStyle: TextStyle(fontSize: 14), prefixIcon: Icon(Icons.account_circle)),
                controller: _maxListEntries,
                inputFormatters: [ FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  maxListEntries = int.tryParse(value) ?? 25000;
                },
              )),
              IconButton( icon: Icon(Icons.arrow_upward), onPressed: () {
                maxListEntries += 1000;
                setState(() { _maxListEntries.text = "$maxListEntries"; });
              }),
              IconButton( icon: Icon(Icons.arrow_downward), onPressed: () {
                maxListEntries -= 1000;
                if (maxListEntries < 150) maxListEntries = 150;
                setState(() { _maxListEntries.text = "$maxListEntries"; });
              }),
              ])
            ]),

            TableRow(children: [Text(""), SizedBox(width: 20,), SizedBox(height: 40,)]),
          ])
    ])));
  }

}

