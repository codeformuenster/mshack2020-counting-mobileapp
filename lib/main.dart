import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:muensterZaehltDartOpenapi/api.dart';

/// Creates instance of [Dio] to be used in the remote layer of the app.
Dio createDio(BaseOptions baseConfiguration) {
  var dio = Dio(baseConfiguration);
  dio.interceptors.addAll([
    // interceptor to retry failed requests
    // interceptor to add bearer token to requests
    // interceptor to refresh access tokens
    // interceptor to log requests/responses
    // etc.
  ]);

  return dio;
}

/// Creates Dio Options for initializing a Dio client.
///
/// [baseUrl] Base url for the configuration
/// [connectionTimeout] Timeout when sending data
/// [connectionReadTimeout] Timeout when receiving data
BaseOptions createDioOptions(
    String baseUrl, int connectionTimeout, int connectionReadTimeout) {
  return BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: connectionTimeout,
    receiveTimeout: connectionReadTimeout,
  );
}

/// Creates an instance of the backend API with default options.
MuensterZaehltDartOpenapi createMyApi() {
  const baseUrl = 'https://counting-backend.codeformuenster.org';
  final options = createDioOptions(baseUrl, 10000, 10000);
  final dio = createDio(options);
  return MuensterZaehltDartOpenapi(dio: dio);
}

void main() {
  runApp(MuensterZaehltApp());
}

// DefaultApi createAPI() {
//   const baseUrl = 'https://counting-backend.codeformuenster.org/';
//   ApiClient apiClient = ApiClient(basePath: baseUrl);
//   DefaultApi defaultApi = DefaultApi(apiClient);
//   return defaultApi;
// }

class MuensterZaehltApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Münster zählt',
      theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.red,
          // This makes the visual density adapt to the platform that you run
          // the app on. For desktop platforms, the controls will be smaller and
          // closer together (more dense) than on mobile platforms.
          visualDensity: VisualDensity.adaptivePlatformDensity,
          scaffoldBackgroundColor: Colors.yellow),
      home: MyHomePage(title: 'Münster zählt'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _fullcounter = 0;
  int _emptycounter = 0;
  MuensterZaehltDartOpenapi api = createMyApi();

  void _incrementFullCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _fullcounter++;
    });
  }

  Future<Position> _getPosition() async {
    LocationPermission permission = await checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    } else if (permission == LocationPermission.deniedForever) {
      print("Location denied forever");
      return null;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      Position position =
          await getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      print(position);
      return position;
    } else {
      print("Location denied");
      return null;
    }
  }

  Future<Response<Object>> _postCount(
      double long, double lat, int count) async {
    Response<Object> response = await api.dio.post("/counts/", data: {
      "long": long,
      "lat": lat,
      "count": count,
      "timestamp": DateTime.now().toIso8601String()
    });
    return response;
  }

  Future<Response<Object>> _readCountIds() async {
    Response<Object> response = await api.dio.get("/counts");
    return response;
  }

  void _incrementEmptyCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _emptycounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.all(16.0),
        childAspectRatio: 8.0 / 9.0,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              _incrementFullCounter();
              _getPosition()
                  .then((value) =>
                      _postCount(value.longitude, value.latitude, 1)
                          .then((value) => print(value.data)))
                  .catchError((e) {
                print("Got error: ${e.error}");
                return 1;
              });
            },
            child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Alles voll hier'),
                          SizedBox(height: 8.0),
                          Center(
                              child: Column(
                            children: [
                              Text(
                                '💩',
                                style: TextStyle(fontSize: 82),
                              ),
                              Text("Vollzähler"),
                              Text(
                                '$_fullcounter',
                              ),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ],
                )),
          ),
          GestureDetector(
              onTap: () {
                _incrementEmptyCounter();
                _getPosition()
                    .then((value) =>
                        _postCount(value.longitude, value.latitude, 0)
                            .then((value) => print(value.data)))
                    .catchError((e) {
                  print("Got error: ${e.error}");
                  return 1;
                });
              },
              child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Alles OK'),
                            SizedBox(height: 8.0),
                            Center(
                                child: Column(
                              children: [
                                Text(
                                  '😎',
                                  style: TextStyle(fontSize: 82),
                                ),
                                Text("Leerzähler"),
                                Text(
                                  '$_emptycounter',
                                ),
                              ],
                            )),
                          ],
                        ),
                      ),
                    ],
                  ))),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementFullCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
