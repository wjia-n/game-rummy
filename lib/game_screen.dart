import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class _Card {
  final int rank; // 1=A .. 13=K
  final int suit; // 0=spade 1=heart 2=diamond 3=club
  const _Card(this.rank, this.suit);
  String get rankLabel =>
      rank == 1 ? 'A' : rank == 11 ? 'J' : rank == 12 ? 'Q' : rank == 13 ? 'K' : '$rank';
  String get suitLabel => '♠♥♦♣'[suit];
  bool get red => suit == 1 || suit == 2;
  int get value => rank == 1 ? 15 : (rank >= 11 ? 10 : rank);
  @override
  bool operator ==(Object o) => o is _Card && o.rank == rank && o.suit == suit;
  @override
  int get hashCode => rank * 4 + suit;
}

class RummyScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const RummyScreen({super.key, required this.players, required this.callbacks});
  @override
  State<RummyScreen> createState() => _RummyScreenState();
}

class _RummyScreenState extends State<RummyScreen> {
  final _rnd = Random();
  late List<List<_Card>> _hands;
  late List<List<List<_Card>>> _table;
  List<_Card> _stock = [];
  List<_Card> _discard = [];
  int _turn = 0;
  int _round = 1;
  bool _drew = false;
  bool _over = false;
  final Set<_Card> _sel = {};

  int get _n => widget.players.length;
  List<_Card> get _hand => _hands[_turn];
  bool get _isBotTurn => widget.players[_turn].isBot;

  @override
  void initState() {
    super.initState();
    _hands = List.generate(_n, (_) => []);
    _table = List.generate(_n, (_) => []);
    _newRound();
  }

  void _newRound() {
    final deck = [_Card(0, 0)]; // placeholder replaced below
    deck.clear();
    for (var s = 0; s < 4; s++) {
      for (var r = 1; r <= 13; r++) {
        deck.add(_Card(r, s));
      }
    }
    deck.shuffle(_rnd);
    for (var i = 0; i < _n; i++) {
      _hands[i] = deck.sublist(0, 7);
      deck.removeRange(0, 7);
      _table[i] = [];
    }
    _stock = deck;
    _discard = [_stock.removeLast()];
    _turn = 0;
    _drew = false;
    _sel.clear();
    setState(() {});
    widget.callbacks.setActivePlayer(0);
    _maybeBot();
  }

  void _reshuffleIfNeeded() {
    if (_stock.isEmpty && _discard.length > 1) {
      final top = _discard.removeLast();
      _stock = _discard..shuffle(_rnd);
      _discard = [top];
    }
  }

  // ---------- meld logic ----------
  bool _validMeld(List<_Card> cs) {
    if (cs.length < 3) return false;
    final sameRank = cs.every((c) => c.rank == cs[0].rank);
    if (sameRank) {
      final suits = cs.map((c) => c.suit).toSet();
      return suits.length == cs.length && cs.length <= 4;
    }
    final sameSuit = cs.every((c) => c.suit == cs[0].suit);
    if (!sameSuit) return false;
    final ranks = cs.map((c) => c.rank).toList()..sort();
    for (var i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) return false;
    }
    return true;
  }

  List<_Card>? _findMeld(List<_Card> hand) {
    final byRank = <int, List<_Card>>{};
    for (final c in hand) {
      byRank.putIfAbsent(c.rank, () => []).add(c);
    }
    for (final e in byRank.values) {
      final seen = <int>{};
      final cards = <_Card>[];
      for (final c in e) {
        if (seen.add(c.suit)) cards.add(c);
      }
      if (cards.length >= 3) return cards.take(4).toList();
    }
    final bySuit = <int, List<_Card>>{};
    for (final c in hand) {
      bySuit.putIfAbsent(c.suit, () => []).add(c);
    }
    for (final e in bySuit.values) {
      final sorted = e.toList()..sort((a, b) => a.rank.compareTo(b.rank));
      final uniq = <_Card>[];
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

  // ---------- human actions ----------
  void _drawStock() {
    if (_drew || _isBotTurn || _over) return;
    _reshuffleIfNeeded();
    if (_stock.isEmpty) return;
    _hand.add(_stock.removeLast());
    _drew = true;
    Sfx.tap();
    setState(() {});
  }

  void _takeDiscard() {
    if (_drew || _isBotTurn || _over || _discard.isEmpty) return;
    _hand.add(_discard.removeLast());
    _drew = true;
    Sfx.tap();
    setState(() {});
  }

  void _toggleSelect(_Card c) {
    if (!_drew || _isBotTurn || _over) return;
    Sfx.tap();
    setState(() {
      if (_sel.contains(c)) {
        _sel.remove(c);
      } else {
        _sel.add(c);
      }
    });
  }

  void _layMeld() {
    final cs = _sel.toList();
    if (!_validMeld(cs)) return;
    for (final c in cs) {
      _hand.remove(c);
    }
    _table[_turn].add(cs);
    _sel.clear();
    Sfx.move();
    setState(() {});
    if (_hand.isEmpty) _endRound(_turn);
  }

  void _discardSelected() {
    if (_sel.length != 1) return;
    final c = _sel.first;
    _hand.remove(c);
    _discard.add(c);
    _sel.clear();
    Sfx.click();
    if (_hand.isEmpty) {
      _endRound(_turn);
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    _turn = (_turn + 1) % _n;
    _drew = false;
    _sel.clear();
    widget.callbacks.setActivePlayer(_turn);
    setState(() {});
    _maybeBot();
  }

  // ---------- bot ----------
  void _maybeBot() {
    if (_over || !_isBotTurn) return;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _over) return;
      _botMove();
    });
  }

  bool _botWants(_Card top) {
    final h = _hands[_turn];
    final sameRank = h.where((c) => c.rank == top.rank).length;
    if (sameRank >= 2) return true;
    for (final c in h) {
      if (c.suit == top.suit && (c.rank - top.rank).abs() == 1) return true;
    }
    return false;
  }

  Future<void> _botMove() async {
    if (_over || !_isBotTurn) return;
    // draw
    _reshuffleIfNeeded();
    if (_discard.isNotEmpty && _stock.isNotEmpty && _botWants(_discard.last)) {
      _hand.add(_discard.removeLast());
    } else if (_stock.isNotEmpty) {
      _hand.add(_stock.removeLast());
    } else if (_discard.isNotEmpty) {
      _hand.add(_discard.removeLast());
    }
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || _over) return;
    // meld greedily
    var laid = true;
    while (laid) {
      laid = false;
      final m = _findMeld(_hand);
      if (m != null) {
        for (final c in m) {
          _hand.remove(c);
        }
        _table[_turn].add(m);
        laid = true;
      }
    }
    Sfx.move();
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || _over) return;
    // discard highest deadwood
    if (_hand.isEmpty) {
      _endRound(_turn);
      return;
    }
    _hand.sort((a, b) => b.value.compareTo(a.value));
    _discard.add(_hand.removeAt(0));
    setState(() {});
    if (_hand.isEmpty) {
      _endRound(_turn);
    } else {
      _nextTurn();
    }
  }

  // ---------- rounds ----------
  void _endRound(int winnerIdx) {
    if (_over) return;
    for (var i = 0; i < _n; i++) {
      if (i == winnerIdx) continue;
      widget.players[i].score += _hands[i].fold(0, (s, c) => s + c.value);
    }
    widget.callbacks.refreshHud();
    Sfx.win();
    if (_round >= 3) {
      _over = true;
      var wi = 0;
      for (var i = 1; i < _n; i++) {
        if (widget.players[i].score < widget.players[wi].score) wi = i;
      }
      widget.callbacks.finish(
        winner: widget.players[wi],
        headline: '🎴 RUMMY! ${widget.players[wi].name} takes the crown!',
        subline: 'Lowest score wins — what a card shark. 🃏',
      );
      return;
    }
    final wname = widget.players[winnerIdx].name;
    _round++;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WajihaDialog(
        title: '🎴 RUMMY!',
        emoji: '🃏',
        children: [
          Text('$wname emptied their hand!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Round $_round of 3 — deadwood added. Stay frosty! ❄️',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          WajihaButton(
            label: 'Deal me in!',
            emoji: '🎴',
            onTap: () {
              Navigator.pop(context);
              _newRound();
            },
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------
  Widget _miniCard(_Card c, {bool selected = false, VoidCallback? onTap, double w = 46}) {
    final t = ThemeController.of(context).theme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: w * 1.42,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? t.primary : Colors.black12, width: selected ? 3 : 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(c.rankLabel,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: c.red ? Colors.red.shade700 : Colors.grey.shade900)),
            Text(c.suitLabel,
                style: TextStyle(fontSize: 16, color: c.red ? Colors.red.shade700 : Colors.grey.shade900)),
          ],
        ),
      ),
    );
  }

  Widget _cardBack(double w) {
    final t = ThemeController.of(context).theme;
    return Container(
      width: w,
      height: w * 1.42,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        gradient: t.headerGradient,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: const Center(child: Text('🎴', style: TextStyle(fontSize: 18))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final me = widget.players[_turn];
    final canAct = !_isBotTurn && !_over;
    final selList = _sel.toList();
    final meldOk = selList.length >= 3 && _validMeld(selList);

    return Column(
      children: [
        ScoreChips(players: widget.players, activeIndex: _turn),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Round $_round of 3 • low score wins 🏆',
              style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        TurnBanner(
            player: me,
            action: _isBotTurn
                ? ' is thinking… 🤖'
                : (_drew ? ' — meld or discard!' : ' — draw a card!')),
        const SizedBox(height: 6),
        // table melds
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var i = 0; i < _n; i++)
                if (_table[i].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${widget.players[i].emoji} ${widget.players[i].name}\'s melds',
                            style: TextStyle(
                                color: t.muted, fontWeight: FontWeight.w800, fontSize: 12)),
                        const SizedBox(height: 2),
                        for (final meld in _table[i])
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final c in meld) _miniCard(c, w: 36),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              if (_table.every((m) => m.isEmpty))
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No melds yet — be the first to show off! ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.muted, fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        ),
        // stock + discard
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: canAct && !_drew ? _drawStock : null,
              child: Column(
                children: [
                  _stock.isEmpty
                      ? Container(
                          width: 52,
                          height: 74,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.muted)),
                          child: const Center(child: Text('🈳')))
                      : _cardBack(52),
                  Text('Stock ${_stock.length}',
                      style: TextStyle(color: t.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: canAct && !_drew ? _takeDiscard : null,
              child: Column(
                children: [
                  _discard.isEmpty
                      ? Container(
                          width: 52,
                          height: 74,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.muted)))
                      : _miniCard(_discard.last, w: 52),
                  Text('Discard ♻️',
                      style: TextStyle(color: t.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // hand
        Container(
          height: 108,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _isBotTurn
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _hand.length && i < 10; i++) _cardBack(40),
                    if (_hand.length > 10)
                      Text(' +${_hand.length - 10}',
                          style: TextStyle(color: t.muted, fontWeight: FontWeight.w800)),
                  ],
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final c in _hand) _miniCard(c, selected: _sel.contains(c), onTap: () => _toggleSelect(c)),
                  ],
                ),
        ),
        // actions
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: canAct
              ? (_drew
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        WajihaButton(
                          label: 'Meld ✨',
                          onTap: meldOk ? _layMeld : () {},
                          primary: meldOk,
                          fontSize: 16,
                        ),
                        const SizedBox(width: 10),
                        WajihaButton(
                          label: 'Discard 🗑️',
                          onTap: _sel.length == 1 ? _discardSelected : () {},
                          primary: _sel.length == 1,
                          fontSize: 16,
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        WajihaButton(label: 'Draw Stock 🎴', onTap: _drawStock, fontSize: 16),
                        const SizedBox(width: 10),
                        WajihaButton(
                            label: 'Take Discard ♻️',
                            onTap: _discard.isEmpty ? () {} : _takeDiscard,
                            primary: _discard.isNotEmpty,
                            fontSize: 16),
                      ],
                    ))
              : Text(_over ? 'Game over! 🎉' : '🤖 ${me.name} is playing…',
                  style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
