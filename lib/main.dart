import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

const int p1 = 1;
const int p2 = 2;

void main() async {
 SystemChrome.setEnabledSystemUIOverlays([]);
 runApp(MyApp());
}

class MyApp extends StatelessWidget {
 @override
 Widget build(BuildContext context) => MaterialApp(
  home: MyWidget(),
  theme: ThemeData(
   brightness: Brightness.dark,
   highlightColor: Colors.yellow,
   splashColor: Colors.transparent,
  ),
 );
}

class MyWidget extends StatelessWidget {
 final Bloc bloc = Bloc();

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   body: SafeArea(
    child: Center(
     child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
       Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
         children: <Widget>[
          StreamBuilder<bool>(
            stream: bloc.activeSub,
            builder: (context, snapshot) {
             var color = snapshot.data == null ? Colors.grey : snapshot.data == true ? Colors.green : Colors.red;
             return AspectRatio(aspectRatio: 1, child: Container(color: color));
            }),
          StreamBuilder<List<List<int>>>(
            stream: bloc.boardSub,
            builder: (context, snapshot) {
             final board = snapshot.data;
             return GridView.builder(
              primary: false,
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
              itemCount: 9,
              itemBuilder: (context, index) {
               final player = board != null ? board[(index / 3).floor()][index % 3] : null;
               final icon = player == p1 ? 'images/x.png' : player == p2 ? 'images/o.png' : null;
               return Padding(
                padding: const EdgeInsets.all(1),
                child: Material(
                 color: Colors.black,
                 child: InkWell(child: icon != null ? Image.asset(icon) : null, onTap: () => bloc.onTap(index, false)),
                ),
               );
              },
             );
            }),
         ],
        ),
       ),
       FlatButton(child: Text('New Game'), onPressed: () => bloc.newGame(false)),
       StreamBuilder<int>(
         stream: bloc.winnerSub,
         builder: (context, snapshot) {
          if (snapshot.data == null) return SizedBox.shrink();
          return Text('Player ${snapshot.data} won!');
         }),
      ],
     ),
    ),
   ),
  );
 }
}

class Bloc {
 Bloc() {
  if (ip != null)
   Socket.connect(ip, 4567).then(listen);
  else
   ServerSocket.bind(InternetAddress.anyIPv4, 4567).then((s) {
    serverSocket = s;
    serverSocket.listen(listen);
   });
 }

 final Board board = Board();
 final String ip = null; // '10.0.128.126';
 Socket socket;
 ServerSocket serverSocket;
 bool playing = false;
 bool initiator = false;

 final BehaviorSubject<List<List<int>>> boardSub = BehaviorSubject<List<List<int>>>();
 final BehaviorSubject<bool> activeSub = BehaviorSubject<bool>();
 final BehaviorSubject<int> winnerSub = BehaviorSubject<int>();

 void listen(Socket s) {
  socket = s;
  socket.map((data) => String.fromCharCodes(data).trim()).listen((data) {
   if (data.startsWith('ng'))
    newGame(true);
   else if (data.startsWith('tap:'))
    onTap(int.parse(data.split(':')[1]), true);
  });
 }

 void write(String data) {
  socket?.write(data);
 }

 void onTap(int index, bool fromRemote) {
  if (!playing) return;

  bool active = activeSub.value ?? false;
  if (!active && !fromRemote) return;

  if (board.set(index % 3, (index / 3).floor(), player(fromRemote))) {
   if (!fromRemote) write('tap:$index');
   boardSub.add(board.b);
   activeSub.add(fromRemote);
   var winner = board.won();
   if (winner != null) {
    playing = false;
    winnerSub.add(winner);
    activeSub.add(null);
   }
  }
 }

 void newGame(bool fromRemote) {
  reset();
  playing = true;
  initiator = !fromRemote;
  activeSub.add(!fromRemote);
  if (!fromRemote) write('ng');
 }

 void reset() {
  board.reset();
  boardSub.add(board.b);
  winnerSub.add(null);
 }

 int player(bool fromRemote) {
  if (initiator) return fromRemote ? p2 : p1;
  else return fromRemote ? p1 : p2;
 }
}

class Board {
 Board() {
  reset();
 }

 List<List<int>> b;

 void reset() => b = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];

 bool set(int x, int y, int player) {
  assert(x >= 0 && x < 3);
  assert(y >= 0 && y < 3);
  if (b[y][x] != 0) return false;
  b[y][x] = player;
  return true;
 }

 int won() {
  if (sum.contains('111')) return p1;
  else if (sum.contains('222')) return p2;
  return null;
 }

 String get sum => '''
${b[0][0]}${b[0][1]}${b[0][2]},
${b[1][0]}${b[1][1]}${b[1][2]},
${b[2][0]}${b[2][1]}${b[2][2]},
${b[0][0]}${b[1][0]}${b[2][0]},
${b[0][1]}${b[1][1]}${b[2][1]},
${b[0][2]}${b[1][2]}${b[2][2]},
${b[0][0]}${b[1][1]}${b[2][2]},
${b[0][2]}${b[1][1]}${b[2][0]}
''';
}
