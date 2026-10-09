import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// A single physical card: rank 1(A)..13(K), suit 0=spade 1=heart 2=diamond 3=club.
@immutable
class RummyCard {
  final int rank;
  final int suit;
  const RummyCard(this.rank, this.suit);

  String get rankLabel => rank == 1
      ? 'A'
      : rank == 11
          ? 'J'
          : rank == 12
              ? 'Q'
              : rank == 13
                  ? 'K'
                  : '$rank';
  String get suitLabel => '♠♥♦♣'[suit];
  bool get red => suit == 1 || suit == 2;

  /// Deadwood value: Ace 15, faces 10, numbers at face.
  int get deadwood => rank == 1 ? 15 : (rank >= 11 ? 10 : rank);

  @override
  bool operator ==(Object o) =>
      o is RummyCard && o.rank == rank && o.suit == suit;
  @override
  int get hashCode => rank * 4 + suit;
}

/// One seat at the table.
class RummySeat {
  String name;
  final bool isBot;
  final List<RummyCard> hand = [];
  final List<List<RummyCard>> melds = [];
  int score = 0; // total deadwood across rounds (low wins)
  int roundWins = 0; // rounds taken (match tie-break)

  RummySeat({required this.name, required this.isBot});
}

/// Engine-owned turn phases. The UI only renders; it never advances turns.
enum RummyPhase {
  idle, // before a deal / between rounds
  dealing, // animated deal in progress
  awaitingDraw, // human turn: must draw
  aiTurn, // bot is playing its visible sub-steps
  awaitingAction, // human drew: may meld, lay off, then must discard
  roundEnd, // scoring dialog showing
  gameOver, // match finished
}

/// The authoritative Rummy engine: owns all state, phases, timers and the
/// watchdog. Stuck states are impossible by construction: every phase either
/// waits for a legal human action (buttons always present) or has a live
/// engine timer driving the next step, and the watchdog recovers any AI
/// phase found without one.
class RummyEngine extends ChangeNotifier {
  RummyEngine({
    required List<String> names,
    required List<int> botSeats,
    required this.difficulty,
    this.roundsToWin = 3,
  })  : _rand = Random(),
        seats = [
          for (var i = 0; i < names.length; i++)
            RummySeat(name: names[i], isBot: botSeats.contains(i))
        ];

  final Random _rand;
  final List<RummySeat> seats;
  final int difficulty; // 0 easy, 1 medium, 2 hard
  final int roundsToWin;

  RummyPhase phase = RummyPhase.idle;
  int turn = 0; // seat index whose turn it is
  int round = 1;
  final List<RummyCard> stock = [];
  final List<RummyCard> discard = [];
  final List<RummyCard> selection = [];

  /// Narration of the current table event ("Yasmin draws from the stock…").
  String narration = 'Welcome to the table! 🃏';
  int lastWinner = -1;

  // Animation hints the UI reads: the most recent visible moves.
  RummyCard? lastDrawn;
  RummyCard? lastDiscarded;
  int lastMeldSeat = -1;
  int lastMeldIndex = -1;
  int dealtCount = 0; // seats dealt during the dealing phase

  Timer? _aiTimer;
  Timer? _watchdog;
  int _aiGen = 0; // bumps on every schedule/cancel; kills stale callbacks
  int _lastProgress = 0; // ms timestamp of last engine progress
  bool _disposed = false;

  int get seatCount => seats.length;
  RummySeat get activeSeat => seats[turn];
  bool get humanToAct =>
      !activeSeat.isBot &&
      (phase == RummyPhase.awaitingDraw || phase == RummyPhase.awaitingAction);
  int get stockCount => stock.length;
  RummyCard? get discardTop => discard.isEmpty ? null : discard.last;

  // ------------------------------------------------------------- lifecycle
  void start() {
    _startWatchdog();
    newRound();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _lastProgress = DateTime.now().millisecondsSinceEpoch;
    _watchdog = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (_disposed) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      // If the engine owes a bot turn but no bot timer is live, restart it.
      if (phase == RummyPhase.aiTurn && _aiTimer == null) {
        if (now - _lastProgress > 1200) {
          narrate('${activeSeat.name} picks up the pace…');
          _scheduleAi(const Duration(milliseconds: 300), _botStep);
        }
      }
      // Absolute safety: a bot turn may never run forever.
      if (phase == RummyPhase.aiTurn && now - _lastProgress > 15000) {
        _forceFinishBotTurn();
      }
    });
  }

  void _markProgress() {
    _lastProgress = DateTime.now().millisecondsSinceEpoch;
  }

  void narrate(String s) {
    narration = s;
    _markProgress();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _aiTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  /// Pause all engine timers (app backgrounded / game paused).
  void pauseTimers() {
    _aiTimer?.cancel();
    _aiTimer = null;
    _markProgress();
  }

  /// Resume after pause: restart whichever engine timer was mid-flight
  /// (bot turn or animated deal).
  void resumeTimers() {
    if (_disposed) return;
    _markProgress();
    if (phase == RummyPhase.aiTurn && _aiTimer == null) {
      _scheduleAi(const Duration(milliseconds: 400), _botStep);
    } else if (phase == RummyPhase.dealing && _aiTimer == null) {
      _dealTick();
    }
  }

  // --------------------------------------------------------------- dealing
  void newRound() {
    _aiTimer?.cancel();
    _aiTimer = null;
    _aiGen++;
    final deck = <RummyCard>[
      for (var s = 0; s < 4; s++)
        for (var r = 1; r <= 13; r++) RummyCard(r, s),
    ]..shuffle(_rand);
    for (final seat in seats) {
      seat.hand
        ..clear()
        ..addAll(deck.sublist(0, 7));
      deck.removeRange(0, 7);
      seat.melds.clear();
    }
    stock
      ..clear()
      ..addAll(deck);
    discard
      ..clear()
      ..add(stock.removeLast());
    selection.clear();
    lastDrawn = null;
    lastDiscarded = null;
    lastMeldSeat = -1;
    lastMeldIndex = -1;
    turn = 0;
    dealtCount = 0;
    phase = RummyPhase.dealing;
    narrate('Round $round — dealing the cards… 🎴');
    notifyListeners();
    // Animated deal: one seat per tick, engine-driven.
    _startDealChain();
  }

  int _dealIndex = 0;

  void _startDealChain() {
    _dealIndex = 0;
    _dealTick();
  }

  void _dealTick() {
    if (_disposed) return;
    final gen = _aiGen;
    _aiTimer?.cancel();
    _aiTimer = Timer(const Duration(milliseconds: 400), () {
      _aiTimer = null;
      if (_disposed || gen != _aiGen) return;
      if (_dealIndex < seats.length) {
        dealtCount = _dealIndex + 1;
        _dealIndex++;
        _markProgress();
        notifyListeners();
        _dealTick();
      } else {
        _beginTurn();
      }
    });
  }

  void _beginTurn() {
    _markProgress();
    selection.clear();
    final seat = activeSeat;
    if (seat.isBot) {
      phase = RummyPhase.aiTurn;
      _botStage = 0; // every bot turn starts at the draw step
      _botDrew = false;
      narrate('🤖 ${seat.name}\'s turn…');
      notifyListeners();
      _scheduleAi(const Duration(milliseconds: 750), _botStep);
    } else {
      phase = RummyPhase.awaitingDraw;
      narrate('${seat.name}, draw a card! 🎴');
      notifyListeners();
    }
  }

  void _scheduleAi(Duration d, void Function() fn) {
    _aiTimer?.cancel();
    final gen = _aiGen;
    _aiTimer = Timer(d, () {
      _aiTimer = null;
      if (_disposed || gen != _aiGen) return;
      fn();
    });
  }

  void _cancelAi() {
    _aiTimer?.cancel();
    _aiTimer = null;
    _aiGen++;
  }

  // ---------------------------------------------------------- human actions
  bool get _canHumanDraw =>
      humanToAct && phase == RummyPhase.awaitingDraw && !activeSeat.isBot;

  bool get _canHumanAct =>
      humanToAct && phase == RummyPhase.awaitingAction && !activeSeat.isBot;

  void drawFromStock() {
    if (!_canHumanDraw) return;
    _reshuffleIfNeeded();
    if (stock.isEmpty) {
      // Shoe is genuinely empty (even after reshuffle): the round cannot
      // continue — score the hands instead of freezing the turn.
      declareDraw();
      return;
    }
    lastDrawn = stock.removeLast();
    activeSeat.hand.add(lastDrawn!);
    phase = RummyPhase.awaitingAction;
    narrate('${activeSeat.name} draws from the stock 🎴');
    notifyListeners();
  }

  void drawFromDiscard() {
    if (!_canHumanDraw || discard.isEmpty) return;
    lastDrawn = discard.removeLast();
    activeSeat.hand.add(lastDrawn!);
    phase = RummyPhase.awaitingAction;
    narrate(
        '${activeSeat.name} picks up ${lastDrawn!.rankLabel}${lastDrawn!.suitLabel} ♻️');
    notifyListeners();
  }

  void toggleSelect(RummyCard card) {
    if (!_canHumanAct) return;
    if (selection.contains(card)) {
      selection.remove(card);
    } else {
      selection.add(card);
    }
    notifyListeners();
  }

  void clearSelection() {
    selection.clear();
    notifyListeners();
  }

  /// Lay the selected cards as a new meld.
  void layMeld() {
    if (!_canHumanAct) return;
    final cards = List<RummyCard>.of(selection);
    if (!isValidMeld(cards)) return;
    for (final c in cards) {
      activeSeat.hand.remove(c);
    }
    activeSeat.melds.add(cards);
    lastMeldSeat = turn;
    lastMeldIndex = activeSeat.melds.length - 1;
    selection.clear();
    narrate(
        '✨ ${activeSeat.name} lays ${cards.map((c) => '${c.rankLabel}${c.suitLabel}').join(' ')}');
    if (activeSeat.hand.isEmpty) {
      _winRound(turn, wentOut: true);
    } else {
      notifyListeners();
    }
  }

  /// Add one selected card to any existing meld (own or another player's).
  void layOff(int meldSeat, int meldIndex) {
    if (!_canHumanAct || selection.length != 1) return;
    if (meldSeat < 0 || meldSeat >= seats.length) return;
    final target = seats[meldSeat].melds;
    if (meldIndex < 0 || meldIndex >= target.length) return;
    final card = selection.first;
    if (!_extendsMeld(target[meldIndex], card)) return;
    activeSeat.hand.remove(card);
    target[meldIndex] = [...target[meldIndex], card]..sort(_cardOrder);
    lastMeldSeat = meldSeat;
    lastMeldIndex = meldIndex;
    selection.clear();
    narrate(
        '➕ ${activeSeat.name} adds ${card.rankLabel}${card.suitLabel} to a meld');
    if (activeSeat.hand.isEmpty) {
      _winRound(turn, wentOut: true);
    } else {
      notifyListeners();
    }
  }

  void discardSelected() {
    if (!_canHumanAct || selection.length != 1) return;
    final card = selection.first;
    activeSeat.hand.remove(card);
    discard.add(card);
    lastDiscarded = card;
    selection.clear();
    narrate('${activeSeat.name} discards ${card.rankLabel}${card.suitLabel} 🗑️');
    if (activeSeat.hand.isEmpty) {
      _winRound(turn, wentOut: true);
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    _markProgress();
    turn = (turn + 1) % seatCount;
    _beginTurn();
  }

  void _reshuffleIfNeeded() {
    if (stock.isEmpty && discard.length > 1) {
      final top = discard.removeLast();
      stock.addAll(discard..shuffle(_rand));
      discard
        ..clear()
        ..add(top);
      narrate('The shoe ran low — discards reshuffled 🔀');
    }
  }

  // ------------------------------------------------------------- bot brain
  int _botStage = 0; // 0 draw, 1 meld, 2 discard
  bool _botDrew = false;

  void _botStep() {
    if (_disposed || phase != RummyPhase.aiTurn) return;
    final seat = activeSeat;
    if (!seat.isBot) {
      _beginTurn();
      return;
    }
    _markProgress();
    switch (_botStage) {
      case 0:
        _botDraw();
        if (phase != RummyPhase.aiTurn) return; // round may have ended
        _botStage = 1;
        _scheduleAi(const Duration(milliseconds: 850), _botStep);
        return;
      case 1:
        final laid = _botMeldAll();
        if (phase != RummyPhase.aiTurn) return; // round may have ended
        if (laid) {
          narrate('✨ ${seat.name} lays a meld!');
          notifyListeners();
          if (seat.hand.isEmpty) {
            _winRound(turn, wentOut: true);
            return;
          }
        }
        _botStage = 2;
        _scheduleAi(const Duration(milliseconds: 850), _botStep);
        return;
      default:
        _botDiscard();
        return;
    }
  }

  void _botDraw() {
    final seat = activeSeat;
    _reshuffleIfNeeded();
    final top = discardTop;
    final wantDiscard = top != null && _botWantsDiscard(top);
    if (wantDiscard && stock.isNotEmpty) {
      // Easy bots sometimes ignore a good discard (mistakes).
      final take = difficulty == 0 ? _rand.nextDouble() < 0.6 : true;
      if (take) {
        lastDrawn = discard.removeLast();
        seat.hand.add(lastDrawn!);
        narrate(
            '🤖 ${seat.name} takes ${lastDrawn!.rankLabel}${lastDrawn!.suitLabel} from the discards ♻️');
        _botDrew = true;
        notifyListeners();
        return;
      }
    }
    if (stock.isNotEmpty) {
      lastDrawn = stock.removeLast();
      seat.hand.add(lastDrawn!);
      narrate('🤖 ${seat.name} draws from the stock 🎴');
      _botDrew = true;
      notifyListeners();
      return;
    }
    if (top != null) {
      lastDrawn = discard.removeLast();
      seat.hand.add(lastDrawn!);
      narrate('🤖 ${seat.name} takes the last discard ♻️');
      notifyListeners();
    } else {
      // Nothing to draw at all: score the round instead of stalling.
      declareDraw();
      return;
    }
    _botDrew = true;
  }

  /// Would this discard help the bot's hand?
  bool _botWantsDiscard(RummyCard top) {
    final hand = activeSeat.hand;
    var sameRank = 0;
    for (final c in hand) {
      if (c.rank == top.rank) sameRank++;
    }
    if (sameRank >= 2) return true;
    for (final c in hand) {
      if (c.suit == top.suit && (c.rank - top.rank).abs() <= 2) return true;
    }
    if (difficulty >= 2) {
      // Hard bots also grab high-value deadwood reducers.
      if (top.deadwood >= 10) {
        final dead = _deadwoodOf(hand);
        if (dead >= 25) return true;
      }
    }
    return false;
  }

  bool _botMeldAll() {
    final seat = activeSeat;
    var laidAny = false;
    var guard = 0;
    while (guard++ < 8) {
      final meld = findMeld(seat.hand);
      if (meld == null) break;
      for (final c in meld) {
        seat.hand.remove(c);
      }
      seat.melds.add(meld);
      lastMeldSeat = turn;
      lastMeldIndex = seat.melds.length - 1;
      laidAny = true;
      // Bots also lay off spare cards onto any meld.
      _botLayOffs();
      if (seat.hand.isEmpty) break;
    }
    if (seat.hand.isNotEmpty) _botLayOffs();
    return laidAny;
  }

  void _botLayOffs() {
    final seat = activeSeat;
    var guard = 0;
    var changed = true;
    while (changed && guard++ < 10) {
      changed = false;
      for (final c in List<RummyCard>.of(seat.hand)) {
        var placed = false;
        for (var s = 0; s < seats.length && !placed; s++) {
          for (var m = 0; m < seats[s].melds.length && !placed; m++) {
            if (_extendsMeld(seats[s].melds[m], c)) {
              seats[s].melds[m] = [...seats[s].melds[m], c]..sort(_cardOrder);
              seat.hand.remove(c);
              lastMeldSeat = s;
              lastMeldIndex = m;
              changed = true;
              placed = true;
            }
          }
        }
      }
    }
  }

  void _botDiscard() {
    final seat = activeSeat;
    if (seat.hand.isEmpty) {
      _winRound(turn, wentOut: true);
      return;
    }
    final pick = _chooseDiscard(seat.hand);
    seat.hand.remove(pick);
    discard.add(pick);
    lastDiscarded = pick;
    _botStage = 0;
    _botDrew = false;
    narrate('🤖 ${seat.name} discards ${pick.rankLabel}${pick.suitLabel} 🗑️');
    notifyListeners();
    if (seat.hand.isEmpty) {
      _winRound(turn, wentOut: true);
    } else {
      _scheduleAi(const Duration(milliseconds: 700), () {
        if (_disposed) return;
        _nextTurn();
      });
    }
  }

  /// Pick the safest, least-useful card to throw away.
  RummyCard _chooseDiscard(List<RummyCard> hand) {
    final scored = <RummyCard, double>{};
    for (final c in hand) {
      var usefulness = 0.0;
      for (final o in hand) {
        if (identical(o, c)) continue;
        if (o.rank == c.rank) usefulness += 3; // set potential
        if (o.suit == c.suit) {
          final d = (o.rank - c.rank).abs();
          if (d == 1) usefulness += 4;
          else if (d == 2) usefulness += 2;
        }
      }
      // High deadwood cards are attractive discards.
      var danger = 0.0;
      if (difficulty >= 1) {
        // Medium+: don't feed the next player obvious meld pieces.
        final recent = discard.length >= 3
            ? discard.sublist(discard.length - 3)
            : discard;
        for (final r in recent) {
          if (r.suit == c.suit && (r.rank - c.rank).abs() == 1) danger += 6;
          if (r.rank == c.rank) danger += 4;
        }
      }
      if (difficulty >= 2) {
        // Hard: hold high cards a touch less, value flexibility more.
        usefulness *= 1.15;
      }
      scored[c] = c.deadwood * 1.4 - usefulness * 3 - danger;
    }
    RummyCard best = hand.first;
    var bestScore = double.negativeInfinity;
    for (final e in scored.entries) {
      if (e.value > bestScore) {
        bestScore = e.value;
        best = e.key;
      }
    }
    if (difficulty == 0 && _rand.nextDouble() < 0.25) {
      // Easy bots blunder: random discard now and then.
      return hand[_rand.nextInt(hand.length)];
    }
    return best;
  }

  /// Watchdog last resort: if a bot turn stalls beyond the limit, force the
  /// turn to complete legally so the game can never freeze.
  void _forceFinishBotTurn() {
    if (phase != RummyPhase.aiTurn || !activeSeat.isBot) return;
    narrate('⚡ ${activeSeat.name} hurries up!');
    final seat = activeSeat;
    if (!_botDrew) {
      _reshuffleIfNeeded();
      if (stock.isNotEmpty) seat.hand.add(stock.removeLast());
    }
    _botMeldAll();
    if (seat.hand.isNotEmpty) {
      final pick = _chooseDiscard(seat.hand);
      seat.hand.remove(pick);
      discard.add(pick);
      lastDiscarded = pick;
    }
    _botStage = 0;
    _botDrew = false;
    notifyListeners();
    if (seat.hand.isEmpty) {
      _winRound(turn, wentOut: true);
    } else {
      _nextTurn();
    }
  }

  // ---------------------------------------------------------------- melds
  /// A meld: 3+ cards, either same rank (distinct suits, max 4) or a
  /// same-suit sequence. Ace is low only — no round-the-corner.
  static bool isValidMeld(List<RummyCard> cards) {
    if (cards.length < 3) return false;
    final sameRank = cards.every((c) => c.rank == cards[0].rank);
    if (sameRank) {
      final suits = cards.map((c) => c.suit).toSet();
      return suits.length == cards.length && cards.length <= 4;
    }
    final sameSuit = cards.every((c) => c.suit == cards[0].suit);
    if (!sameSuit) return false;
    final ranks = cards.map((c) => c.rank).toList()..sort();
    for (var i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) return false;
    }
    return true;
  }

  /// A single card can extend a meld if the result stays a valid meld.
  static bool _extendsMeld(List<RummyCard> meld, RummyCard card) {
    if (meld.contains(card)) return false;
    return isValidMeld([...meld, card]);
  }

  /// Public: can [card] legally extend [meld]? Used by the UI to offer only
  /// legal lay-off targets.
  static bool canLayOff(List<RummyCard> meld, RummyCard card) =>
      _extendsMeld(meld, card);

  /// Find one meld hiding in a hand (sets first, then runs).
  static List<RummyCard>? findMeld(List<RummyCard> hand) {
    final byRank = <int, List<RummyCard>>{};
    for (final c in hand) {
      byRank.putIfAbsent(c.rank, () => []).add(c);
    }
    for (final group in byRank.values) {
      final distinct = <RummyCard>[];
      final seenSuits = <int>{};
      for (final c in group) {
        if (seenSuits.add(c.suit)) distinct.add(c);
      }
      if (distinct.length >= 3) return distinct.take(4).toList();
    }
    final bySuit = <int, List<RummyCard>>{};
    for (final c in hand) {
      bySuit.putIfAbsent(c.suit, () => []).add(c);
    }
    for (final group in bySuit.values) {
      final sorted = group.toList()..sort(_cardOrder);
      final uniq = <RummyCard>[];
      for (final c in sorted) {
        if (uniq.isEmpty || uniq.last.rank != c.rank) uniq.add(c);
      }
      for (var i = 0; i + 2 < uniq.length; i++) {
        var j = i;
        while (j + 1 < uniq.length && uniq[j + 1].rank == uniq[j].rank + 1) {
          j++;
        }
        if (j - i + 1 >= 3) return uniq.sublist(i, j + 1);
        i = j;
      }
    }
    return null;
  }

  static int _cardOrder(RummyCard a, RummyCard b) {
    final s = a.suit.compareTo(b.suit);
    return s != 0 ? s : a.rank.compareTo(b.rank);
  }

  static int _deadwoodOf(List<RummyCard> hand) =>
      hand.fold(0, (s, c) => s + c.deadwood);

  // ---------------------------------------------------------------- rounds
  void _winRound(int winnerIdx, {required bool wentOut}) {
    _cancelAi();
    phase = RummyPhase.roundEnd;
    lastWinner = winnerIdx;
    seats[winnerIdx].roundWins++;
    for (var i = 0; i < seats.length; i++) {
      if (i != winnerIdx) {
        seats[i].score += _deadwoodOf(seats[i].hand);
      }
    }
    final wname = seats[winnerIdx].name;
    if (round >= roundsToWin) {
      phase = RummyPhase.gameOver;
      final wi = matchWinner();
      narrate('🏆 ${seats[wi].name} wins the match with ${seats[wi].score} deadwood!');
    } else {
      narrate(
          wentOut ? '🎴 RUMMY! $wname goes out!' : '🃏 Shoe exhausted — $wname takes the round!');
    }
    notifyListeners();
  }

  /// Shoe + discards both empty mid-turn: nobody can draw — end the round.
  void declareDraw() {
    if (phase != RummyPhase.awaitingDraw && phase != RummyPhase.aiTurn) return;
    var wi = 0;
    var best = _deadwoodOf(seats[0].hand);
    for (var i = 1; i < seats.length; i++) {
      final d = _deadwoodOf(seats[i].hand);
      if (d < best) {
        best = d;
        wi = i;
      }
    }
    _winRound(wi, wentOut: false);
  }

  /// Match winner: lowest deadwood; ties broken by most round wins,
  /// then by lowest seat index.
  int matchWinner() {
    var wi = 0;
    for (var i = 1; i < seats.length; i++) {
      if (seats[i].score < seats[wi].score ||
          (seats[i].score == seats[wi].score &&
              seats[i].roundWins > seats[wi].roundWins)) {
        wi = i;
      }
    }
    return wi;
  }

  void nextRound() {
    round++;
    lastWinner = -1;
    newRound();
  }

  /// Restart the whole match: zero every seat's deadwood and start round 1.
  void restartMatch() {
    for (final s in seats) {
      s.score = 0;
      s.roundWins = 0;
    }
    round = 1;
    lastWinner = -1;
    newRound();
  }

  void renameSeat(int i, String name) {
    if (i < 0 || i >= seats.length) return;
    final clean = name.trim();
    seats[i].name = clean.isEmpty ? seats[i].name : clean;
    notifyListeners();
  }
}
