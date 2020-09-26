import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:muensterZaehltDartOpenapi/api.dart';
import 'package:latlong/latlong.dart';
import 'package:random_string/random_string.dart';
import 'dart:async';

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

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  List<double> _imageOpacity = [1.0, 1.0, 1.0];
  List<bool> _timerVisible = [false, false, false];
  double _progress = 0;
  Timer timer;
  MuensterZaehltDartOpenapi api = createMyApi();
  MapController mapController = new MapController();
  AnimationController animationController;
  TabController _tabController;
  MarkerLayerOptions markerLayerOptions = new MarkerLayerOptions(
    markers: [],
  );

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: Duration(seconds: 1),
      vsync: this,
    );
    _tabController = TabController(vsync: this, length: 2);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void newMarker(Position position) {
    mapController.move(new LatLng(position.latitude, position.longitude), 18);
    markerLayerOptions.markers.add(new Marker(
      width: 32.0,
      height: 32.0,
      point: new LatLng(position.latitude, position.longitude),
      builder: (ctx) => new Container(
        child: new Image.asset("assets/muensterhack_logo.png"),
      ),
    ));
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
      setState(() {
        _tabController.index = 1;
        if (mapController.ready) {
          Timer(Duration(seconds: 1), () => newMarker(position));
        } else {
          mapController.onReady.then((value) => newMarker(position));
        }
      });
      return position;
    } else {
      print("Location denied");
      return null;
    }
  }

  Future<Response<Object>> _postCount(
      double long, double lat, int count) async {
    String device_id = "mobileapp";
    // Response<Object> response = await api.dio.post("/devices/", data: {
    //   "lon": long,
    //   "lat": lat,
    //   "id": device_id,
    //   "data": {"created_on": DateTime.now().toIso8601String()}
    // });
    // if (response.statusCode != 201) {
    //   return response;
    // }

    Response<Object> response = await api.dio.post("/counts/", data: {
      "device_id": device_id,
      "count": count,
      "timestamp": DateTime.now().toIso8601String(),
      "data": {"longitude": long, "latitude": lat}
    });
    return response;
  }

  Future<Response<Object>> _readCountIds() async {
    Response<Object> response = await api.dio.get("/counts");
    return response;
  }

  void _finishTimer(int count) {
    _getPosition()
        .then((value) => _postCount(value.longitude, value.latitude, count)
            .then((value) => print(value.data)))
        .catchError((e) {
      print("Got error: ${e.error}");
      return 1;
    });
  }

  void _cancelTimer() {
    if (timer != null) {
      timer.cancel();
      timer = null;
      setState(() {
        _progress = 0.0;
        _timerVisible = [false, false, false];
        _imageOpacity = [1.0, 1.0, 1.0];
      });
    }
  }

  void _startTimer(int idx) {
    print("Start timer");
    setState(() {
      _progress = 0.0;
      _timerVisible[idx] = true;
      _imageOpacity[idx] = 0.5;
    });
    timer = new Timer.periodic(
      Duration(milliseconds: 17),
      (Timer timer) => setState(
        () {
          if (_progress >= 1) {
            _cancelTimer();
            int count;
            switch (idx) {
              case 2:
                count = 50;
                break;
              case 1:
                count = 10;
                break;
              case 0:
              default:
                count = 0;
            }
            _finishTimer(count);
          } else {
            _progress += 0.017;
            // print(_progress);
          }
        },
      ),
    );
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
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.add_to_photos)),
            Tab(icon: Icon(Icons.map)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          Column(
            children: <Widget>[
              GestureDetector(
                onTapDown: (details) => {_startTimer(0)},
                onTapUp: (details) => {_cancelTimer()},
                child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('Alles frei'),
                              SizedBox(height: 8.0),
                              Stack(
                                children: [
                                  Opacity(
                                    opacity: _imageOpacity[0],
                                    child: Image.asset("assets/background.png"),
                                  ),
                                  Visibility(
                                    visible: _timerVisible[0],
                                    child: Center(
                                      heightFactor: 4.0,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 64,
                                        backgroundColor: Colors.yellow,
                                        valueColor:
                                            new AlwaysStoppedAnimation<Color>(
                                                Colors.red),
                                        value: _progress,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    )),
              ),
              GestureDetector(
                  onTapDown: (details) => {_startTimer(1)},
                  onTapUp: (details) => {_cancelTimer()},
                  child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Abstände werden eingehalten'),
                                SizedBox(height: 8.0),
                                Stack(
                                  children: [
                                    Opacity(
                                      opacity: _imageOpacity[1],
                                      child: Image.asset("assets/level1.png"),
                                    ),
                                    Visibility(
                                      visible: _timerVisible[1],
                                      child: Center(
                                        heightFactor: 4.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 64,
                                          backgroundColor: Colors.yellow,
                                          valueColor:
                                              new AlwaysStoppedAnimation<Color>(
                                                  Colors.red),
                                          value: _progress,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ))),
              GestureDetector(
                  onTapDown: (details) => {_startTimer(2)},
                  onTapUp: (details) => {_cancelTimer()},
                  child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('Zu viele Menschen'),
                                SizedBox(height: 8.0),
                                Stack(
                                  children: [
                                    Opacity(
                                      opacity: _imageOpacity[2],
                                      child: Image.asset("assets/level2.png"),
                                    ),
                                    Visibility(
                                      visible: _timerVisible[2],
                                      child: Center(
                                        heightFactor: 4.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 64,
                                          backgroundColor: Colors.yellow,
                                          valueColor:
                                              new AlwaysStoppedAnimation<Color>(
                                                  Colors.red),
                                          value: _progress,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ))),
            ],
          ),
          FlutterMap(
            options: new MapOptions(
              center: new LatLng(51.9521213, 7.6404818),
              zoom: 13.0,
            ),
            mapController: mapController,
            layers: [
              new TileLayerOptions(
                  urlTemplate:
                      "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: ['a', 'b', 'c']),
              markerLayerOptions,
            ],
          ),
        ],
      ),
    );
  }
}
