
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const WeatherApp());
}

const bg = Color(0xFF101827);
const panel = Color(0xFF1C293B);
const accent = Color(0xFF58B9F5);

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  bool lightTheme = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Weather Now',
      theme: ThemeData(
        useMaterial3: true,
        brightness: lightTheme ? Brightness.light : Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: lightTheme ? Brightness.light : Brightness.dark,
        ),
        scaffoldBackgroundColor:
            lightTheme ? const Color(0xFFF1F5F9) : bg,
      ),
      home: AuthGate(
        lightTheme: lightTheme,
        onThemeChanged: (value) => setState(() => lightTheme = value),
      ),
    );
  }
}

// ---------------- AUTHENTICATION ----------------
// Demo-only local authentication. Do not use this for real accounts.
// Use Firebase Authentication for production apps.

class AuthGate extends StatefulWidget {
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;

  const AuthGate({
    super.key,
    required this.lightTheme,
    required this.onThemeChanged,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  String? name;
  String? email;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('sessionName');
      email = prefs.getString('sessionEmail');
      loading = false;
    });
  }

  void _login(String userName, String userEmail) {
    setState(() {
      name = userName;
      email = userEmail;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionName');
    await prefs.remove('sessionEmail');
    if (!mounted) return;
    setState(() {
      name = null;
      email = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (name == null || email == null) {
      return LoginScreen(onLogin: _login);
    }

    return WeatherHome(
      name: name!,
      email: email!,
      onLogout: _logout,
      lightTheme: widget.lightTheme,
      onThemeChanged: widget.onThemeChanged,
    );
  }
}

class LoginScreen extends StatefulWidget {
  final Function(String, String) onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isSignup = false;
  bool obscurePassword = true;
  String error = '';

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty ||
        (isSignup && name.isEmpty)) {
      setState(() => error = 'Please fill in all fields.');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }

    if (password.length < 6) {
      setState(() => error = 'Password must be at least 6 characters.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final users = prefs.getStringList('users') ?? [];

    if (isSignup) {
      final exists = users.any((item) {
        final data = jsonDecode(item);
        return data['email'] == email;
      });

      if (exists) {
        setState(() => error = 'Account already exists. Please log in.');
        return;
      }

      users.add(jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }));

      await prefs.setStringList('users', users);
      await prefs.setString('sessionName', name);
      await prefs.setString('sessionEmail', email);
      widget.onLogin(name, email);
    } else {
      Map<String, dynamic>? found;

      for (final item in users) {
        final data = jsonDecode(item) as Map<String, dynamic>;
        if (data['email'] == email &&
            data['password'] == password) {
          found = data;
          break;
        }
      }

      if (found == null) {
        setState(() => error = 'Incorrect email or password.');
        return;
      }

      await prefs.setString('sessionName', found['name']);
      await prefs.setString('sessionEmail', found['email']);
      widget.onLogin(found['name'], found['email']);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.cloud_rounded,
                    size: 85, color: accent),
                const SizedBox(height: 16),
                const Text(
                  'Weather Now',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSignup
                      ? 'Create your account'
                      : 'Welcome back!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 35),
                if (isSignup)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (isSignup) const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() =>
                            obscurePassword = !obscurePassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (error.isNotEmpty)
                  Text(error,
                      style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    isSignup ? 'Create Account' : 'Login',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isSignup = !isSignup;
                      error = '';
                    });
                  },
                  child: Text(isSignup
                      ? 'Already have an account? Login'
                      : "Don't have an account? Sign up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- WEATHER MODEL ----------------

class WeatherData {
  final String city;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final List<dynamic> hourlyTimes;
  final List<dynamic> hourlyTemps;
  final List<dynamic> dailyDates;
  final List<dynamic> dailyMax;
  final List<dynamic> dailyMin;
  final List<dynamic> dailyCodes;

  WeatherData({
    required this.city,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.hourlyTimes,
    required this.hourlyTemps,
    required this.dailyDates,
    required this.dailyMax,
    required this.dailyMin,
    required this.dailyCodes,
  });

  factory WeatherData.fromJson(
      String city, Map<String, dynamic> json) {
    final current = json['current'];
    final hourly = json['hourly'];
    final daily = json['daily'];

    return WeatherData(
      city: city,
      temperature: (current['temperature_2m'] as num).toDouble(),
      feelsLike: (current['apparent_temperature'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      windSpeed: (current['wind_speed_10m'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      isDay: current['is_day'] == 1,
      hourlyTimes: hourly['time'],
      hourlyTemps: hourly['temperature_2m'],
      dailyDates: daily['time'],
      dailyMax: daily['temperature_2m_max'],
      dailyMin: daily['temperature_2m_min'],
      dailyCodes: daily['weather_code'],
    );
  }
}

// ---------------- WEATHER SERVICE ----------------

class WeatherService {
  static Future<WeatherData> getWeather(
      String city) async {
    final geoUrl = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': city,
        'count': '1',
        'language': 'en',
        'format': 'json',
      },
    );

    final geoResponse = await http.get(geoUrl);

    if (geoResponse.statusCode != 200) {
      throw Exception('Unable to search for this city.');
    }

    final geoData = jsonDecode(geoResponse.body);
    final results = geoData['results'];

    if (results == null || results.isEmpty) {
      throw Exception('City not found. Try another city.');
    }

    final location = results[0];
    final latitude = location['latitude'];
    final longitude = location['longitude'];

    final weatherUrl = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m',
        'hourly': 'temperature_2m,weather_code',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'auto',
        'forecast_days': '7',
      },
    );

    final weatherResponse = await http.get(weatherUrl);

    if (weatherResponse.statusCode != 200) {
      throw Exception('Unable to get weather data.');
    }

    final weatherJson = jsonDecode(weatherResponse.body);

    return WeatherData.fromJson(
      '${location['name']}, ${location['country']}',
      weatherJson,
    );
  }
}

// ---------------- WEATHER HELPERS ----------------

String weatherDescription(int code) {
  if (code == 0) return 'Clear Sky';
  if (code == 1) return 'Mainly Clear';
  if (code == 2) return 'Partly Cloudy';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Rain Showers';
  if (code >= 85 && code <= 86) return 'Snow Showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Unknown';
}

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0) {
    return isDay ? Icons.wb_sunny : Icons.nightlight_round;
  }
  if (code <= 3) return Icons.cloud;
  if (code <= 48) return Icons.foggy;
  if (code <= 67) return Icons.grain;
  if (code <= 77) return Icons.ac_unit;
  if (code <= 82) return Icons.water_drop;
  if (code <= 86) return Icons.ac_unit;
  return Icons.thunderstorm;
}

String dayName(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  return days[parsed.weekday - 1];
}

String hourLabel(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  final hour = parsed.hour;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour $suffix';
}

// ---------------- WEATHER HOME ----------------

class WeatherHome extends StatefulWidget {
  final String name;
  final String email;
  final Future<void> Function() onLogout;
  final bool lightTheme;
  final ValueChanged<bool> onThemeChanged;

  const WeatherHome({
    super.key,
    required this.name,
    required this.email,
    required this.onLogout,
    required this.lightTheme,
    required this.onThemeChanged,
  });

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final searchController = TextEditingController();

  WeatherData? weather;
  bool loading = false;
  String error = '';
  int selectedIndex = 0;
  bool fahrenheit = false;

  List<String> savedCities = [];
  List<String> recentCities = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _searchCity('Guntur');
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      savedCities = prefs.getStringList('savedCities') ?? [];
      recentCities = prefs.getStringList('recentCities') ?? [];
      fahrenheit = prefs.getBool('fahrenheit') ?? false;
    });
  }

  double _convertTemperature(double value) {
    if (fahrenheit) return (value * 9 / 5) + 32;
    return value;
  }

  String _temperature(double value) {
    return '${_convertTemperature(value).round()}°${fahrenheit ? 'F' : 'C'}';
  }

  Future<void> _searchCity(String city) async {
    if (city.trim().isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      loading = true;
      error = '';
    });

    try {
      final result = await WeatherService.getWeather(city.trim());
      final prefs = await SharedPreferences.getInstance();

      final recent = prefs.getStringList('recentCities') ?? [];
      recent.removeWhere(
          (item) => item.toLowerCase() == result.city.toLowerCase());
      recent.insert(0, result.city);

      if (recent.length > 8) {
        recent.removeLast();
      }

      await prefs.setStringList('recentCities', recent);

      if (!mounted) return;

      setState(() {
        weather = result;
        recentCities = recent;
        loading = false;
        searchController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleSavedCity() async {
    if (weather == null) return;

    final city = weather!.city;
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (savedCities.contains(city)) {
        savedCities.remove(city);
      } else {
        savedCities.add(city);
      }
    });

    await prefs.setStringList('savedCities', savedCities);
  }

  Future<void> _removeSavedCity(String city) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      savedCities.remove(city);
    });

    await prefs.setStringList('savedCities', savedCities);
  }

  Future<void> _changeUnit(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => fahrenheit = value);
    await prefs.setBool('fahrenheit', value);
  }

  Widget _weatherCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? panel
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _searchCity,
            decoration: InputDecoration(
              hintText: 'Search city...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? panel
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: () => _searchCity(searchController.text),
          icon: const Icon(Icons.arrow_forward),
          style: IconButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentWeather() {
    if (weather == null) return const SizedBox();

    final current = weather!;

    return _weatherCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  current.city,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _toggleSavedCity,
                icon: Icon(
                  savedCities.contains(current.city)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Icon(
            weatherIcon(current.weatherCode, isDay: current.isDay),
            size: 85,
            color: accent,
          ),
          const SizedBox(height: 10),
          Text(
            _temperature(current.temperature),
            style: const TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            weatherDescription(current.weatherCode),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Feels like ${_temperature(current.feelsLike)}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _weatherInfo(
                  Icons.water_drop,
                  'Humidity',
                  '${current.humidity}%',
                ),
              ),
              Expanded(
                child: _weatherInfo(
                  Icons.air,
                  'Wind',
                  '${current.windSpeed.round()} km/h',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherInfo(IconData icon, String title, String value) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 27),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildHourlyForecast() {
    if (weather == null) return const SizedBox();

    final current = weather!;
    final now = DateTime.now();

    int startIndex = current.hourlyTimes.indexWhere((time) {
      final parsed = DateTime.tryParse(time.toString());
      return parsed != null && !parsed.isBefore(now);
    });

    if (startIndex < 0) startIndex = 0;

    final endIndex =
        (startIndex + 12).clamp(0, current.hourlyTimes.length);

    return _weatherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hourly Forecast',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: endIndex - startIndex,
              itemBuilder: (context, index) {
                final i = startIndex + index;
                final time = current.hourlyTimes[i].toString();
                final temp =
                    (current.hourlyTemps[i] as num).toDouble();

                return Container(
                  width: 75,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Text(hourLabel(time),
                          style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      const Icon(Icons.wb_cloudy,
                          color: accent, size: 25),
                      const SizedBox(height: 12),
                      Text(
                        _temperature(temp),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyForecast() {
    if (weather == null) return const SizedBox();

    final current = weather!;

    return _weatherCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7-Day Forecast',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          ...List.generate(current.dailyDates.length, (index) {
            final date = current.dailyDates[index].toString();
            final max = (current.dailyMax[index] as num).toDouble();
            final min = (current.dailyMin[index] as num).toDouble();
            final code = (current.dailyCodes[index] as num).toInt();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      index == 0 ? 'Today' : dayName(date),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(weatherIcon(code), color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      weatherDescription(code),
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  Text(
                    _temperature(max),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _temperature(min),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        if (weather != null) {
          await _searchCity(weather!.city.split(',').first);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Weather Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          _buildSearchBar(),
          const SizedBox(height: 20),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (weather != null && !loading) ...[
            _buildCurrentWeather(),
            const SizedBox(height: 18),
            _buildHourlyForecast(),
            const SizedBox(height: 18),
            _buildDailyForecast(),
          ],
          if (recentCities.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Recent Searches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentCities.map((city) {
                return ActionChip(
                  avatar: const Icon(Icons.history, size: 16),
                  label: Text(city),
                  onPressed: () =>
                      _searchCity(city.split(',').first),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Saved Cities',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        if (savedCities.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'No saved cities yet.\nSave a city from the home screen.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...savedCities.map((city) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.location_city, color: accent),
              title: Text(city),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeSavedCity(city),
              ),
              onTap: () {
                setState(() => selectedIndex = 0);
                _searchCity(city.split(',').first);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 18),
        _weatherCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.thermostat, color: accent),
                title: const Text('Temperature Unit'),
                subtitle: Text(fahrenheit
                    ? 'Fahrenheit (°F)'
                    : 'Celsius (°C)'),
                trailing: Switch(
                  value: fahrenheit,
                  onChanged: _changeUnit,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.dark_mode, color: accent),
                title: const Text('Dark Theme'),
                trailing: Switch(
                  value: !widget.lightTheme,
                  onChanged: (value) =>
                      widget.onThemeChanged(!value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _weatherCard(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 35,
                backgroundColor: accent,
                child: Icon(Icons.person, size: 40, color: Colors.black),
              ),
              const SizedBox(height: 12),
              Text(
                widget.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(widget.email,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: const Text('Your account information'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        name: widget.name,
                        email: widget.email,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Weather Now • Powered by Open-Meteo',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHomeTab(),
      _buildSavedTab(),
      _buildSettingsTab(),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ---------------- PROFILE SCREEN ----------------

class ProfileScreen extends StatelessWidget {
  final String name;
  final String email;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const CircleAvatar(
              radius: 55,
              backgroundColor: accent,
              child: Icon(Icons.person, size: 65, color: Colors.black),
            ),
            const SizedBox(height: 25),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 35),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Name'),
                subtitle: Text(name),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
