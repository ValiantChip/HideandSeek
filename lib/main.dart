import 'package:objd/core.dart';

List<File> files = [
  setGameStart,
  startGame,
  endGame,
  setSeekerStart,
  setGameHome,
  hidersWin,
  seekersWin,
  game_tick,
  start_seekers,
  setCorner1,
  setCorner2,
  gameSetup,
  addTime,
  setTime,
  tellGameTimeChange(),
  tellGraceTimeChange(),
  convertTime,
  macroTeleport
];

var gameTimer = Score(Entity.PlayerName('gametimer'), 'timer');
var gameStatus = Score(Entity.PlayerName('gamestatus'), 'status');
var seekerTimer = Score(Entity.PlayerName('seekertimer'), 'timer');
var useCorners = Score(Entity.PlayerName('use_corners'), 'status');
var freeSpectate = Score(Entity.PlayerName('free_spectate'), 'status');
var seekerTime = Scoreboard('seekertime');
var gameTime = Scoreboard('gametime');
var tpId = Scoreboard('tp_id');
var teleportTo = Scoreboard('teleport_to', type: 'trigger');
var soundTimer = Scoreboard('sound_timer');

var xPos = Scoreboard('xpos');
var yPos = Scoreboard('ypos');
var zPos = Scoreboard('zpos');

const Time baseGameTime = Time.minutes(6);
const Time baseSeekerTime = Time.minutes(1);

var seekerTeam = TeamSet(Color.Red, 'seekers'); 
var hiderTeam = TeamSet(Color.Blue, 'hiders');

File tick = File('/tick', child: For.of([
  If(Condition.score(gameStatus.matches(1)), then: [game_tick.run()]),
  Effect(EffectType.saturation, entity: Entity.All(), duration: Time.infinite(), showParticles: false),
]));
  
File load = File('/load', child: For.of([
  seekerTime,
  gameTime,
  seekerTeam,
  hiderTeam,
  Command("gamerule doImmediateRespawn true"),
  Scoreboard('time'),
  gameTime['time'].set(baseGameTime.ticks),
  seekerTime['time'].set(baseSeekerTime.ticks),
  useCorners.set(1),
  freeSpectate.set(1),
  Scoreboard.setdisplay(tpId.name, display: 'list'),
]));

class TeamSet extends Widget{
  Color color;
  String name;

  TeamSet(this.color, this.name);

  @override
  generate(Context context) {
    return For.of([
      Team.add(name),
      Team.modify(name, color: color),
      Team.modify(name, friendlyFire: false),
      Team.modify(name, nametag: ModifyTeam.hideForOtherTeams),
      Team.modify(name, seeInvisible: false)
    ]);
  }
}

File startGame = File('/start_game', child: For.of([
  gameSetup.run()
]));

File gameSetup = File('/util/game_setup', child: For.of([
  gameStatus.set(1),
  seekerTimer.setTo(seekerTime['time']),
  tpId['game'].set(1),
  Execute(children: [
    tpId.self.setTo(tpId['game']),
    tpId['game'].add(1),
    teleportToMarker('game_start'),
    Tag.add('ingame'),
    Tag.add('alive'),
    Tag.add('barrier_target'),
    Attribute.add(Entity.Selected(), Attributes.generic_scale, value: -0.75, id: 'hider_scale'),
    //Attribute.add(Entity.Selected(), Attributes.generic_jump_strength, value: -0.5, id: 'hider_jump', modifyType: AttributeModifier.add_multiplied_base),
    Attribute.add(Entity.Selected(), Attributes.generic_movement_speed, value: -0.2, id: 'hider_speed', modifyType: AttributeModifier.add_multiplied_base)
  ]).as(Entity.All(team: Team('hiders'))),
  Execute(children: [
    tpId.self.setTo(tpId['game']),
    tpId['game'].add(1),
    teleportToMarker('seeker_start'),
    Tag.add('ingame'),
    //Attribute.add(Entity.Selected(), Attributes.generic_movement_speed, value: 0.5, id: 'seeker_speed', modifyType: AttributeModifier.add_multiplied_base),
    Attribute.add(Entity.Selected(), Attributes.generic_attack_damage, value: 100, id: 'seeker_damage'),
    Effect(EffectType.resistance, entity: Entity.Selected(), duration: Time.infinite(), amplifier: 10, showParticles: false),
    //Effect(EffectType.glowing, duration: Time.infinite(), showParticles: false)
  ]).as(Entity.All(team: Team('seekers')))
]));

File start_seekers = File('/util/start_seekers', execute: true, child: For.of([
  Execute(children: [PlaySound(Sounds.entity_wither_spawn, 'master', target: Entity.Selected(), volume: 16, minVolume: 1)]).asat(Entity.All(tags: ['ingame'])),
  gameTimer.setTo(gameTime['time']),
  Title(Entity.All(tags: ['ingame']), show: [TextComponent('Ready or Not', color: Color.Red)]),
  Execute(children: [
    teleportToMarker('game_start'),
    Tag.add('barrier_target')
  ]).as(Entity.All(team: Team('seekers')))
]));

File game_tick = File('/game/game_tick', execute: true, child: For.of([
  Trigger.enable(teleportTo[Entity.All(gamemode: Gamemode.spectator, tags: ['ingame'])]),
  Execute(children: [
    teleportSpectator()
  ]).If(Condition.score(freeSpectate.matches(0))),
  cornerRegistration('corner1', 'corner2'),
  checkForSeekerWin(),
  Execute(children: [
    checkCorners('corner1', 'corner2')
  ]).as(Entity.All(tags: ['barrier_target'])).at(Entity.Selected()).unless(Condition.score(useCorners.matches(0))),
  DeathEvent(onDeath: onHiderDeath()),
  timerUpdate(gameTimer, Color.Red, onEnd: hidersWin.run(), tickAt: 10.seconds),
  timerUpdate(seekerTimer, Color.Blue, onEnd: start_seekers.run(), tickAt: 10.seconds),
  checkForTrigger()
]));

File hidersWin = File('/util/hiders_win', child: For.of([
  Title(Entity.All(tags: ['ingame']), show: [TextComponent('Hiders Win', color: hiderTeam.color)]),
  endGame.run()
]));

File seekersWin = File('/util/seekers_win', child: For.of([
  Title(Entity.All(tags: ['ingame']), show: [TextComponent('Seekers Win', color: seekerTeam.color)]),
  endGame.run()
]));

File endGame = File('/end_game', execute: true, child: For.of([
  gameTimer.set(-1),
  Execute(children: [
    Attribute.remove(Entity.Selected(), Attributes.generic_scale, id: 'hider_scale'),
    Attribute.remove(Entity.Selected(), Attributes.generic_movement_speed, id: 'hider_speed'),
    Attribute.remove(Entity.Selected(), Attributes.generic_jump_strength, id: 'hider_jump'),
    SetGamemode(Gamemode.adventure)
  ]).as(Entity.All(team: Team('hiders'))),
  Execute(children: [
    Attribute.remove(Entity.Selected(), Attributes.generic_movement_speed, id: 'seeker_speed'),
    Attribute.remove(Entity.Selected(), Attributes.generic_attack_damage, id: 'seeker_damage'),
    Effect.clear(Entity.Selected(), EffectType.resistance),
    Effect.clear(Entity.Selected(), EffectType.glowing)
  ]).as(Entity.All(team: Team('seekers'))),
  Execute(
    children: [
      Tag.remove('alive'),
      teleportToMarker('game_home'),
      tpId.self.reset(),
      teleportTo.self.reset(),
      Execute(children: [PlaySound(Sounds.entity_player_levelup, 'master', target: Entity.Selected(), volume: 16, minVolume: 1)]).asat(Entity.All(tags: ['ingame'])),
      Tag.remove('ingame'),
    ]
  ).as(Entity.All(tags: ['ingame'])),
  gameStatus.set(0)
]));

Widget teleportToMarker(String name) => macroTeleport.executer(StorageArgument(name, 'pos'));
File macroTeleport = File('/util/macroteleport', child: MacroTeleport(Entity.Selected()));

class MacroTeleport extends Widget {
  Entity entity;
  MacroTeleport(this.entity);
  Widget generate(Context context){
    return Command('\$teleport @s \$(x) \$(y) \$(z)');
  }
}


File enable_corners = File('/settings/enable_corners', child: useCorners.set(1));
File disable_corners = File('/settings/disable_corners', child: useCorners.set(0));
File enable_free_spectate = File('/settings/enable_free_spectate', child: freeSpectate.set(1));
File disable_free_spectate = File('/settings/disable_free_spectate', child: freeSpectate.set(0));

Widget checkForTrigger() => Execute(children: [
  Execute(children: [
    Tag.add('teleporting'),
    Execute(children: [
      Teleport.entity(Entity.All(tags: ['teleporting'], limit: 1), to: Entity.Selected())
    ]).as(Entity.All(tags: ['ingame'])).If(Condition.score(tpId.self.isEqual(teleportTo[Entity.All(tags: ['teleporting'], limit: 1)]))),
    Tag.remove('teleporting')
  ]).as(Entity.Selected(gamemode: Gamemode.spectator, tags: ['ingame'])),
  teleportTo.self.set(0) 
]).as(Entity.All(scores: [teleportTo.self.matchesRange(Range.from(1))]));

Widget teleportSpectator() => Command('execute as @a[gamemode=spectator, tag=ingame] at @s run tp @s @a[sort=nearest, tag=ingame, limit=1, gamemode=!spectator]');

Widget timerUpdate(Score score, Color color, {Widget? onEnd, Time? tickAt}) => Execute(children: [score.subtract(1), IndexedFile('timer', path: '/timer',execute: true,child: For.of([
  prepareDisplayScore('temp', score),
  Execute(children: [
    Title.actionbar(Entity.All(tags: ["ingame"]), show: [TextComponent.score(Score(Entity.PlayerName('minutes'), 'temp'), color: color), TextComponent(':0', color: color), TextComponent.score(Score(Entity.PlayerName('seconds'), 'temp',), color: color)])
  ]).If(Condition.score(Score(Entity.PlayerName('seconds'), 'temp').matchesRange(Range.to(9)))),
  Execute(children: [
    Title.actionbar(Entity.All(tags: ["ingame"]), show: [TextComponent.score(Score(Entity.PlayerName('minutes'), 'temp'), color: color), TextComponent(':', color: color), TextComponent.score(Score(Entity.PlayerName('seconds'), 'temp',), color: color)])
  ]).unless(Condition.score(Score(Entity.PlayerName('seconds'), 'temp').matchesRange(Range.to(9)))),
  If(Condition.and([Condition.score(Score(Entity.PlayerName('ticks'), 'temp').matches(0)), Condition.score(score.matchesRange(Range.to(tickAt?.ticks)))]),then: [
    Execute(children: [PlaySound(Sounds.block_bamboo_break, 'master', target: Entity.Selected(), volume: 16, minVolume: 1)]).asat(Entity.All(tags: ['ingame'])),
  ]),
  If(score.matches(0), then: [
    onEnd ?? Nil()
  ])
]))]).If(Condition(score.matchesRange(Range.from(0))));

Widget prepareDisplayScore(String out, Score time){
  var to = Scoreboard(out, addIntoLoad: false);
  var seconds = to['seconds'];
  var minutes = to['minutes'];
  var ticks = to['ticks'];

  return For.of([
    Score.con(20),
    Score.con(60),
    Score.con(10),
    ticks.setTo(time),
    ticks.modulo(Score.con(20)),
    seconds.setTo(time),
    seconds.multiplyByScore(Score.con(10)),
    seconds.divideByScore(Score.con(20)),
    seconds.add(9),
    seconds.divideByScore(Score.con(10)),
    minutes.setTo(seconds),
    minutes.divideByScore(Score.con(60)),
    seconds.modulo(Score.con(60)),
  ]);
}

File setGameStart = File('/create/set_game_start', child: SetGameMarker('game_start'));
File setSeekerStart = File('/create/set_seeker_start', child: SetGameMarker('seeker_start'));
File setGameHome = File('/create/set_game_home', child: SetGameMarker('game_home'));

File setCorner1 = File('/create/set_corner_1', child: SetCorner('corner1'));
File setCorner2 = File('/create/set_corner_2', child: SetCorner('corner2'));

class SetGameMarker extends Widget {
  String name;
  SetGameMarker(this.name);

  Widget generate(Context context){
    return Storage(name).modify('pos', DataModify.set({'x':context.doubleArgument('x'), 'y':context.doubleArgument('y'), 'z':context.doubleArgument('z')}));
  }
}

class SetCorner extends Widget {
  String name;
  SetCorner(this.name);

  Widget generate(Context context){
    var pos = Scoreboard(name + 'pos');
    return For.of([
      pos['x'].set(context.intArgument('x')),
      pos['y'].set(context.intArgument('y')),
      pos['z'].set(context.intArgument('z')),
    ]);
  }
}

File tellGameTimeChange(){
  final TextComponent prefix = TextComponent('Game Time has been changed to ');
  return File('/tell_gametime_change', child: For.of([
          prepareDisplayScore('temp', gameTime['time']),
          Execute(children: [
            Tellraw(Entity.All(), show: [prefix, TextComponent.score(Score(Entity.PlayerName('minutes'), 'temp')), TextComponent(':0'), TextComponent.score(Score(Entity.PlayerName('seconds'), 'temp',))])
          ]).If(Condition.score(Score(Entity.PlayerName('seconds'), 'temp').matchesRange(Range.to(9)))),
          Execute(children: [
            Tellraw(Entity.All(), show: [prefix, TextComponent.score(Score(Entity.PlayerName('minutes'), 'temp')), TextComponent(':'), TextComponent.score(Score(Entity.PlayerName('seconds'), 'temp',))])
          ]).unless(Condition.score(Score(Entity.PlayerName('seconds'), 'temp').matchesRange(Range.to(9)))),
        ]));
}

File tellGraceTimeChange() {
  final TextComponent prefix = TextComponent('Grace Time has been changed to ');
  return File('/tell_gracetime_change', child: For.of([
          prepareDisplayScore('temp', seekerTime['time']),
          Execute(children: [
            Tellraw(Entity.All(), show: [prefix, TextComponent.score(Score(Entity.PlayerName('minutes'), 'temp')), TextComponent(':0'), TextComponent.score(Score(Entity.PlayerName('seconds'), 'temp',))])
          ]).If(Condition.score(Score(Entity.PlayerName('seconds'), 'temp').matchesRange(Range.to(9)))),
          Execute(children: [
            Tellraw(Entity.All(), show: [prefix, TextComponent.score(Score(Entity.PlayerName('minutes'), 'temp')), TextComponent(':'), TextComponent.score(Score(Entity.PlayerName('seconds'), 'temp',))])
          ]).unless(Condition.score(Score(Entity.PlayerName('seconds'), 'temp').matchesRange(Range.to(9)))),
        ]));
}

File convertTime = File('/convert_time', child: TimeConvert());

class TimeConvert extends Widget {
  Widget generate(Context context) {
    var from = context.scoreArgument('from');
    var to = context.stringArgument('to');
    return prepareDisplayScore(to, from);
  }
}

Widget cornerRegistration(String start, String end) {
  var startPos = Scoreboard(start + 'pos');
  var endPos = Scoreboard(end + 'pos');
  var temp = Scoreboard('temp');
  return For.of([
    temp['x'].setTo(startPos['x']),
    temp['y'].setTo(startPos['y']),
    temp['z'].setTo(startPos['z']),
    startPos['x'].setToSmallest(endPos['x']),
    startPos['y'].setToSmallest(endPos['y']),
    startPos['z'].setToSmallest(endPos['z']),
    endPos['x'].setToBiggest(temp['x']),
    endPos['y'].setToBiggest(temp['y']),
    endPos['z'].setToBiggest(temp['z'])
  ]);
}

Widget checkCorners(String start, String end) {
  var startPos = Scoreboard(start + 'pos');
  var endPos = Scoreboard(end + 'pos');
  var outsideBounds = Scoreboard('outside_bounds');
  return For.of([
    Storage.set('tele', key: 'Pos', value: {'x':'~', 'y':'~', 'z':'~'}),
    outsideBounds.self.set(0),
    xPos.self.setToData(Data.get(Entity.Selected(), path: 'Pos[0]')),
    yPos.self.setToData(Data.get(Entity.Selected(), path: 'Pos[1]')),
    zPos.self.setToData(Data.get(Entity.Selected(), path: 'Pos[2]')),
    If(Condition.score(xPos.self.isSmaller(startPos['x'])), then: [
      Storage.copyScore('tele', key: 'Pos.x', score: startPos['x'], datatype: 'int'),
      outsideBounds.self.set(1)
    ]),
    If(Condition.score(yPos.self.isSmaller(startPos['y'])), then: [
      Storage.copyScore('tele', key: 'Pos.y', score: startPos['y'], datatype: 'int'),
      outsideBounds.self.set(1)
    ]),
    If(Condition.score(zPos.self.isSmaller(startPos['z'])), then: [
      Storage.copyScore('tele', key: 'Pos.z', score: startPos['z'], datatype: 'int'),
      outsideBounds.self.set(1)
    ]),
    If(Condition.score(xPos.self.isBigger(endPos['x'])), then: [
      Storage.copyScore('tele', key: 'Pos.x', score: endPos['x'], datatype: 'int'),
      outsideBounds.self.set(1)
    ]),
    If(Condition.score(yPos.self.isBigger(endPos['y'])), then: [
      Storage.copyScore('tele', key: 'Pos.y', score: endPos['y'], datatype: 'int'),
      outsideBounds.self.set(1)
    ]),
    If(Condition.score(zPos.self.isBigger(endPos['z'])), then: [
      Storage.copyScore('tele', key: 'Pos.z', score: endPos['z'], datatype: 'int'),
      outsideBounds.self.set(1)
    ]),
    If(Condition.score(outsideBounds.self.matches(1)), then: [
      macroTeleport.executer(StorageArgument('tele', 'Pos')),
    ])
  ]);
}

Widget checkForSeekerWin() => 
  Execute(children: [
    seekersWin.run()
  ]).unless(Condition.entity(Entity.All(team: Team('hiders'), tags: ['alive'])));

Widget onHiderDeath() => For.of([
  teleportToMarker('game_home'),
  If(Condition.entity(Entity.Selected(tags: ['alive'], team: Team('hiders'))), then: [
    SetGamemode(Gamemode.spectator, target: Entity.Selected()),
    Tag.remove("alive", entity: Entity.Selected()),
    Attribute.remove(Entity.Selected(), Attributes.generic_scale, id: 'hider_scale'),
    Attribute.remove(Entity.Selected(), Attributes.generic_movement_speed, id: 'hider_speed'),
    Attribute.remove(Entity.Selected(), Attributes.generic_jump_strength, id: 'hider_jump'),
    teleportToMarker('game_start')
  ]),
  ]
  );

File addTime = File('add_time', child: TimeAdder());

File setTime = File('set_time', child: TimeSetter());


class TimeAdder extends Widget {
  Widget generate(Context context){
    var minutes = context.intArgument('minutes');
    var seconds = context.intArgument('seconds');
    var scoreboard = context.stringArgument('scoreboard');
    var temp = Score(Entity.PlayerName('temp'), 'temp');
    var score = Score(Entity.PlayerName('time'), scoreboard, addNew: false);
    var tempMinutes = Score(Entity.PlayerName('minutes'), 'temp');
    var tempSeconds = Score(Entity.PlayerName('seconds'), 'temp');

    return For.of([
      Score.con(20),
      Score.con(60),
      Score.con(0),
      tempMinutes.set(minutes),
      tempSeconds.set(seconds),
      temp.set(0),
      temp.addScore(tempMinutes),
      temp.multiplyByScore(Score.con(60)),
      temp.addScore(tempSeconds),
      temp.multiplyByScore(Score.con(20)),
      score.addScore(temp),
      score.setToBiggest(Score.con(0))
    ]);
  }
} 
class TimeSetter extends Widget {
  Widget generate(Context context){
    var minutes = context.intArgument('minutes');
    var seconds = context.intArgument('seconds');
    var scoreboard = context.stringArgument('scoreboard');
    var temp = Score(Entity.PlayerName('temp'), 'temp');
    var score = Score(Entity.PlayerName('time'), scoreboard, addNew: false);

    return For.of([
      Score.con(20),
      Score.con(60),
      Score.con(0),
      temp.add(minutes),
      temp.multiplyByScore(Score.con(60)),
      temp.add(seconds),
      temp.multiplyByScore(Score.con(20)),
      score.setTo(temp),
      score.setToBiggest(Score.con(0))
    ]);
  }
} 