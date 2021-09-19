import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

int season_number = -1;
int week_number = -1;
List<Conference> conf_lst = [];
List<String> ap_poll = List.filled(25, '');
List<BetInfo> bet_lst = [];

List<String> conference_names = [
  "American Athletic - East",
  "American Athletic - West",
  "Atlantic Coast - Atlantic",
  "Atlantic Coast - Coastal",
  "Big 12",
  "Big Ten - East",
  "Big Ten - West",
  "Conference USA - East",
  "Conference USA - West",
  "FBS Independents",
  "Mid-American - East",
  "Mid-American - West",
  "Mountain West - Mountain",
  "Mountain West - West",
  "Pac-12 - North",
  "Pac-12 - South",
  "SEC - East",
  "SEC - West",
  "Sun Belt - East",
  "Sun Belt - West"
];

void print_teams() {
  print('Conferences: ' + conf_lst.length.toString());
  conf_lst.forEach((conf) => {
    conf.teams.forEach((team) => {
      print(conf.name + ': ' + team)
    })
  });
}

void print_ap_poll() {
  print('AP Poll: ');
  ap_poll.asMap().forEach((i, team) => {
    print(i.toString() + ') ' + team)
  });
}

void print_bets() {
  print('Bets: ');
  bet_lst.forEach((bet) => {
    print('Home: ' + bet.home_team + ' (' + bet.home_line.toString() + ')\n' +
      'Away: ' + bet.away_team + ' (' + bet.away_line.toString() + ')\n' +
      'Spread: ' + bet.spread.toString() + '\n' +
      'Over/Under: ' + bet.overunder.toString())
  });
}

void print_ap_matchups() {
  var builder = MatchupBuilder();
  var lst = builder.ap_matchup();
  lst.forEach((bet) {
    var a = bet.home_team + ' (' + bet.home_line.toString() + '), ';
    var b = bet.away_team + ' (' + bet.away_line.toString() + '), ';
    var c = bet.spread.toString() + ', ' + bet.overunder.toString();
    print(a + b + c);
  });
}

void print_conf_matchups(String name) {
  var builder = MatchupBuilder();
  var lst = builder.conf_matchup(name);
  lst.forEach((bet) {
    var a = bet.home_team + ' (' + bet.home_line.toString() + '), ';
    var b = bet.away_team + ' (' + bet.away_line.toString() + '), ';
    var c = bet.spread.toString() + ', ' + bet.overunder.toString();
    print(a + b + c);
  });
}

class Conference {
  Conference(this.name);

  String name;
  List<String> teams = [];

  void add_team(String n) {
    teams.add(n);
  }
}

class BetInfo {
  BetInfo(this.home_team, this.away_team, this.home_line, this.away_line, this.spread, this.overunder);

  String home_team;
  String away_team;
  double spread;
  double overunder;
  int home_line;
  int away_line;
}

class ConferenceBuilder {
  int conf_index(String c) {
    int idx = -1;
    conf_lst.asMap().forEach((i, el) => {
      if(el.name == c) {
        idx = i
      }
    });
    return idx;
  }

  void add(String conf, String team, dynamic rank) {
    int i = conf_index(conf);
    if(i == -1) {
      i = conf_lst.length;
      conf_lst.add(Conference(conf));
    }
    conf_lst[i].add_team(team);

    if(rank != null) {
      ap_poll[rank-1] = team;
    }
  }
}

class MatchupBuilder {
  List<BetInfo> ap_matchup() {
    List<BetInfo> res = [];
    for(var i = 0; i < bet_lst.length; i++) {
      for(var j = 0; j < ap_poll.length; j++) {
        if(bet_lst[i].home_team == ap_poll[j] || bet_lst[i].away_team == ap_poll[j]) {
          res.add(bet_lst[i]);
          break;
        }
      }
    }
    return res;
  }

  List<BetInfo> conf_matchup(String conf_name) {
    List<BetInfo> res = [];
    conf_lst.forEach((conf) => {
      if(conf.name == conf_name) {
        conf.teams.forEach((team) => {
          bet_lst.forEach((bet) => {
            if(bet.home_team == team || bet.away_team == team) {
              res.add(bet)
            }
          })
        })
      }
    });
    return res;
  }
}

Future<void> get_conferences() async {
  var builder = ConferenceBuilder();
  var u = Uri.parse("https://api.sportsdata.io/v3/cfb/scores/json/LeagueHierarchy?key=a7dc56f7de7a48a28dc9558c075f4690");
  var client = http.Client();
  try {
    var resp = await client.get(u);
    if(resp.statusCode == 200) {
      var resp_map = convert.jsonDecode(resp.body);
      resp_map.forEach((conf) => {
        conf['Teams'].forEach((team) => {
          builder.add(conf['Name'], team['School'] + ' ' + team['Name'], team['ApRank'])
        })
      });
    }
  } finally {
    client.close();
  }
}

Future<void> get_week() async {
  var u = Uri.parse("https://api.sportsdata.io/v3/cfb/scores/json/CurrentSeasonDetails?key=a7dc56f7de7a48a28dc9558c075f4690");
  var client = http.Client();
  try {
    var resp = await client.get(u);
    if(resp.statusCode == 200) {
      var resp_map = convert.jsonDecode(resp.body) as Map<String, dynamic>;
      season_number = resp_map['Season'];
      week_number = resp_map['ApiWeek'];
      await get_games_by_week();
    }
  } finally {
    client.close();
  }
}

Future<void> get_games_by_week() async {
  var u = Uri.parse("https://api.sportsdata.io/v3/cfb/scores/json/GamesByWeek/"+season_number.toString()+"/"+week_number.toString()+"?key=a7dc56f7de7a48a28dc9558c075f4690");
  var client = http.Client();
  try {
    var resp = await client.get(u);
    if(resp.statusCode == 200) {
      var resp_map = convert.jsonDecode(resp.body);
      resp_map.forEach((game) => {
        if(game['PointSpread'] != null && game['OverUnder'] != null) {
          bet_lst.add(BetInfo(
            game['HomeTeamName'],
            game['AwayTeamName'],
            game['HomeTeamMoneyLine'],
            game['AwayTeamMoneyLine'],
            game['PointSpread'],
            game['OverUnder']))
        }
      });
    }
  } finally {
    client.close();
  }
}
