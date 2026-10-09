import 'package:flutter/material.dart';
import '../engine/rummy_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/felt_table.dart';
import '../theme/felt_themes.dart';
import 'settings_screen.dart';

/// Rummy game screen — the felt table.
///
/// - Every seat has its own visible tray: face-down fans, deadwood score,
///   and an active-seat highlight. Bot turns are fully visible: draws,
///   melds and discards animate on the table with narration, never
///   silently auto-played.
/// - The engine owns the turn state machine (+ watchdog); the UI only
///   renders and forwards human taps.
class GameScreen extends StatefulWidget {
  final RummyEngine engine;
  final RummyAudio audio;
  final RummySettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  bool _paused = false;

  RummyEngine get _e => widget.engine;
  FeltThemeDef get _t => FeltThemes.byId(
      widget.settings.themeId, custom: widget.settings.customTheme);

  // Transition tracking for sounds + phase dialogs.
  RummyPhase _prevPhase = RummyPhase.idle;
  RummyCard? _prevDrawn;
  RummyCard? _prevDiscarded;
  int _prevMeldSeat = -1;
  int _prevMeldIndex = -1;
  int _prevDealt = 0;
  RummyPhase _dialogPhase = RummyPhase.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.addListener(_onChanged);
    widget.audio.startGameMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _e.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _e.removeListener(_onChanged);
    _e.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      if (!_isOver && mounted) _setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  bool get _isOver =>
      _e.phase == RummyPhase.roundEnd || _e.phase == RummyPhase.gameOver;

  void _setPaused(bool v) {
    if (_paused == v) return;
    setState(() => _paused = v);
    if (v) {
      _e.pauseTimers();
      widget.audio.onAppPaused();
    } else {
      _e.resumeTimers();
      widget.audio.onAppResumed();
    }
  }

  // ---------------------------------------------------------- engine watch
  void _onChanged() {
    if (!mounted) return;
    final a = widget.audio;
    // Sounds follow visible table events (human AND bot).
    if (!identical(_e.lastDrawn, _prevDrawn)) {
      _prevDrawn = _e.lastDrawn;
      if (_e.lastDrawn != null) a.draw();
    }
    if (!identical(_e.lastDiscarded, _prevDiscarded)) {
      _prevDiscarded = _e.lastDiscarded;
      if (_e.lastDiscarded != null) a.discard();
    }
    if (_e.lastMeldSeat != _prevMeldSeat ||
        _e.lastMeldIndex != _prevMeldIndex) {
      _prevMeldSeat = _e.lastMeldSeat;
      _prevMeldIndex = _e.lastMeldIndex;
      if (_e.lastMeldSeat >= 0) a.meld();
    }
    if (_e.dealtCount != _prevDealt) {
      _prevDealt = _e.dealtCount;
      if (_e.phase == RummyPhase.dealing) a.deal();
    }
    // Phase transitions: round / match dialogs.
    if (_e.phase != _prevPhase) {
      _prevPhase = _e.phase;
      if (_e.phase == RummyPhase.dealing && _e.round == 1) {
        a.shuffle();
      }
      if (_e.phase == RummyPhase.roundEnd &&
          _dialogPhase != RummyPhase.roundEnd) {
        _dialogPhase = RummyPhase.roundEnd;
        _onRoundEnd();
      } else if (_e.phase == RummyPhase.gameOver &&
          _dialogPhase != RummyPhase.gameOver) {
        _dialogPhase = RummyPhase.gameOver;
        _onGameOver();
      } else if (_e.phase == RummyPhase.dealing) {
        _dialogPhase = RummyPhase.dealing;
      }
    }
  }

  Future<void> _onRoundEnd() async {
    final w = _e.seats[_e.lastWinner];
    final humanWon = !w.isBot;
    if (humanWon) {
      await widget.audio.win();
    } else {
      await widget.audio.lose();
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoundDialog(
        engine: _e,
        audio: widget.audio,
        theme: _t,
      ),
    );
    if (!mounted) return;
    _dialogPhase = RummyPhase.idle;
    _e.nextRound();
    widget.audio.startGameMusic();
  }

  Future<void> _onGameOver() async {
    final wi = _e.matchWinner();
    final w = _e.seats[wi];
    final humanWon = !w.isBot;
    await widget.settings
        .recordGame(humanWon: humanWon, score: w.score);
    if (humanWon) {
      await widget.audio.win();
    } else {
      await widget.audio.lose();
    }
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MatchDialog(
        engine: _e,
        winnerIndex: wi,
        humanWon: humanWon,
        audio: widget.audio,
        theme: _t,
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _dialogPhase = RummyPhase.idle;
      _e.restartMatch();
      widget.audio.startGameMusic();
    } else {
      // App-scoped music: keep playing; menu switches back to menu track.
      Navigator.of(context).pop();
    }
  }

  // ------------------------------------------------------------ human taps
  bool get _canAct =>
      !_paused && !_isOver && _e.humanToAct;

  void _drawStock() {
    if (!_canAct || _e.phase != RummyPhase.awaitingDraw) return;
    if (_e.stockCount == 0) {
      widget.audio.invalid();
      return;
    }
    _e.drawFromStock();
  }

  void _drawDiscard() {
    if (!_canAct || _e.phase != RummyPhase.awaitingDraw) return;
    if (_e.discard.isEmpty) {
      widget.audio.invalid();
      return;
    }
    _e.drawFromDiscard();
  }

  void _toggleCard(RummyCard c) {
    if (!_canAct || _e.phase != RummyPhase.awaitingAction) return;
    widget.audio.click();
    _e.toggleSelect(c);
  }

  void _meld() {
    if (!_canAct || _e.phase != RummyPhase.awaitingAction) return;
    if (!RummyEngine.isValidMeld(_e.selection)) {
      widget.audio.invalid();
      return;
    }
    _e.layMeld();
  }

  void _layOff() {
    if (!_canAct ||
        _e.phase != RummyPhase.awaitingAction ||
        _e.selection.length != 1) {
      widget.audio.invalid();
      return;
    }
    final card = _e.selection.first;
    final targets = <({int seat, int meld, List<RummyCard> cards})>[];
    for (var s = 0; s < _e.seatCount; s++) {
      for (var m = 0; m < _e.seats[s].melds.length; m++) {
        final meld = _e.seats[s].melds[m];
        if (RummyEngine.canLayOff(meld, card)) {
          targets.add((seat: s, meld: m, cards: meld));
        }
      }
    }
    if (targets.isEmpty) {
      widget.audio.invalid();
      return;
    }
    widget.audio.click();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _LayOffSheet(
        targets: targets,
        engine: _e,
        theme: _t,
        audio: widget.audio,
        card: card,
      ),
    );
  }

  void _discard() {
    if (!_canAct ||
        _e.phase != RummyPhase.awaitingAction ||
        _e.selection.length != 1) {
      widget.audio.invalid();
      return;
    }
    _e.discardSelected();
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final t = _t;
    return FeltBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              _setPaused(!_paused);
            },
          ),
          title: Text('Rummy', style: Felt.display(22, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: t.accentLight),
              onPressed: () async {
                widget.audio.click();
                final wasPaused = _paused;
                if (!wasPaused) _setPaused(true);
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    audio: widget.audio,
                    settings: widget.settings,
                  ),
                ));
                widget.audio.configure(
                  musicOn: widget.settings.musicOn,
                  sfxOn: widget.settings.sfxOn,
                  volume: widget.settings.volume,
                );
                if (mounted && !wasPaused) _setPaused(false);
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            ListenableBuilder(
              listenable: _e,
              builder: (_, __) => SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    Text('Round ${_e.round} of ${_e.roundsToWin}',
                        style: Felt.label(12, theme: t)),
                    const SizedBox(height: 6),
                    TurnBanner(text: _e.narration, theme: t),
                    const SizedBox(height: 10),
                    ScoreChips(
                      names: _e.seats.map((s) => s.name).toList(),
                      isBot: _e.seats.map((s) => s.isBot).toList(),
                      scores: _e.seats.map((s) => s.score).toList(),
                      handCounts:
                          _e.seats.map((s) => s.hand.length).toList(),
                      activeIndex: _e.turn,
                      theme: t,
                    ),
                    const SizedBox(height: 10),
                    _SeatTrays(
                        engine: _e,
                        theme: t,
                        cardBack: widget.settings.cardBack),
                    const SizedBox(height: 12),
                    _TableCenter(
                      engine: _e,
                      theme: t,
                      cardBack: widget.settings.cardBack,
                      cardFace: widget.settings.cardFace,
                      canDraw:
                          _canAct && _e.phase == RummyPhase.awaitingDraw,
                      onDrawStock: _drawStock,
                      onDrawDiscard: _drawDiscard,
                    ),
                    const SizedBox(height: 12),
                    _MeldsArea(
                      engine: _e,
                      theme: t,
                      cardFace: widget.settings.cardFace,
                    ),
                    const SizedBox(height: 12),
                    if (_e.humanToAct && !_isOver)
                      _HandStrip(
                        engine: _e,
                        theme: t,
                        cardFace: widget.settings.cardFace,
                        onToggle: _toggleCard,
                      )
                    else
                      _WaitingStrip(engine: _e, theme: t),
                    const SizedBox(height: 12),
                    _ActionBar(
                      engine: _e,
                      theme: t,
                      canAct: _canAct,
                      onDrawStock: _drawStock,
                      onDrawDiscard: _drawDiscard,
                      onMeld: _meld,
                      onLayOff: _layOff,
                      onDiscard: _discard,
                      onClear: () {
                        widget.audio.click();
                        _e.clearSelection();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (_paused && !_isOver)
              _PauseOverlay(
                theme: t,
                audio: widget.audio,
                onResume: () {
                  widget.audio.click();
                  _setPaused(false);
                },
                onRestart: () {
                  widget.audio.click();
                  _dialogPhase = RummyPhase.idle;
                  _setPaused(false);
                  _e.newRound();
                },
                onQuit: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seat trays: every side has its own visible tray — face-down fan, card
// count, deadwood. The active seat glows; bots show a 🤖 tag.
// ---------------------------------------------------------------------------
class _SeatTrays extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  final int cardBack;
  const _SeatTrays(
      {required this.engine, required this.theme, required this.cardBack});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Row(
      children: [
        for (int i = 0; i < engine.seatCount; i++)
          Expanded(
              child: _SeatTray(
                  engine: engine,
                  theme: t,
                  index: i,
                  cardBack: cardBack)),
      ],
    );
  }
}

class _SeatTray extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  final int index;
  final int cardBack;
  const _SeatTray(
      {required this.engine,
      required this.theme,
      required this.index,
      required this.cardBack});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final seat = engine.seats[index];
    final isCurrent =
        engine.turn == index && engine.phase != RummyPhase.idle;
    final dealing = engine.phase == RummyPhase.dealing;
    // Cards are revealed seat-by-seat as the animated deal progresses.
    final shown = dealing
        ? (engine.dealtCount > index ? seat.hand.length : 0)
        : seat.hand.length;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isCurrent
            ? t.playerColors[index].withValues(alpha: 0.28)
            : t.woodDeep.withValues(alpha: 0.6),
        border: Border.all(
          color: isCurrent
              ? t.accentLight
              : t.accent.withValues(alpha: 0.3),
          width: isCurrent ? 2.5 : 1.5,
        ),
        boxShadow: [
          if (isCurrent)
            BoxShadow(
                color: t.accent.withValues(alpha: 0.35), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.playerColors[index],
                  border:
                      Border.all(color: t.accentLight, width: 1.2),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  seat.name,
                  style: Felt.label(11, theme: t),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(seat.isBot ? '🤖 BOT' : '👤 YOU',
              style: Felt.label(9,
                  theme: t,
                  color: t.ivory.withValues(alpha: 0.65))),
          const SizedBox(height: 6),
          // Face-down mini-stack (compact; the count below is exact).
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int k = 0; k < shown && k < 3; k++)
                  Positioned(
                    left: 20.0 + k * 7.0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: PlayingCard(
                        key: ValueKey('deal$index$k'),
                        width: 22,
                        faceDown: true,
                        cardBackStyle: cardBack,
                        theme: t,
                      ),
                    ),
                  ),
                if (shown == 0)
                  Text('—',
                      style: Felt.body(16,
                          theme: t,
                          color: t.ivory.withValues(alpha: 0.4))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('🂠$shown  •  ${seat.score} deadwood',
              style: Felt.label(10,
                  theme: t, color: t.ivory.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table center: stock + discard piles.
// ---------------------------------------------------------------------------
class _TableCenter extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  final int cardBack;
  final int cardFace;
  final bool canDraw;
  final VoidCallback onDrawStock;
  final VoidCallback onDrawDiscard;
  const _TableCenter({
    required this.engine,
    required this.theme,
    required this.cardBack,
    required this.cardFace,
    required this.canDraw,
    required this.onDrawStock,
    required this.onDrawDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final top = engine.discardTop;
    Widget pile({
      required Widget child,
      required String label,
      required VoidCallback? onTap,
    }) =>
        Column(
          children: [
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: onTap != null
                        ? t.accentLight
                        : t.accent.withValues(alpha: 0.35),
                    width: onTap != null ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    if (onTap != null)
                      BoxShadow(
                          color: t.accent.withValues(alpha: 0.4),
                          blurRadius: 10),
                  ],
                ),
                child: child,
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: Felt.label(11,
                    theme: t, color: t.ivory.withValues(alpha: 0.75))),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pile(
          label: 'Stock (${engine.stockCount})',
          onTap: canDraw && engine.stockCount > 0 ? onDrawStock : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PlayingCard(
                width: 64,
                faceDown: true,
                cardBackStyle: cardBack,
                theme: t,
              ),
              if (engine.stockCount == 0)
                Container(
                  width: 64,
                  height: 64 * 1.42,
                  alignment: Alignment.center,
                  child: Text('Empty',
                      style: Felt.label(11, theme: t)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 28),
        pile(
          label: 'Discards',
          onTap: canDraw && engine.discard.isNotEmpty ? onDrawDiscard : null,
          child: top == null
              ? Container(
                  width: 64,
                  height: 64 * 1.42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.4)),
                  ),
                )
              : PlayingCard(
                  width: 64,
                  rank: top.rank,
                  suit: top.suit,
                  cardFaceStyle: cardFace,
                  cardBackStyle: cardBack,
                  theme: t,
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Melds on the table, grouped by seat. The newest meld flashes.
// ---------------------------------------------------------------------------
class _MeldsArea extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  final int cardFace;
  const _MeldsArea(
      {required this.engine, required this.theme, required this.cardFace});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    var any = false;
    for (final s in engine.seats) {
      if (s.melds.isNotEmpty) {
        any = true;
        break;
      }
    }
    if (!any) {
      return Text('No melds on the table yet.',
          style: Felt.body(13,
              theme: t, color: t.ivory.withValues(alpha: 0.55)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int s = 0; s < engine.seatCount; s++)
          if (engine.seats[s].melds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.playerColors[s],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${engine.seats[s].name}\'s melds',
                          style: Felt.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int m = 0;
                            m < engine.seats[s].melds.length;
                            m++)
                          _MeldCards(
                            cards: engine.seats[s].melds[m],
                            theme: t,
                            cardFace: cardFace,
                            fresh: engine.lastMeldSeat == s &&
                                engine.lastMeldIndex == m,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _MeldCards extends StatelessWidget {
  final List<RummyCard> cards;
  final FeltThemeDef theme;
  final int cardFace;
  final bool fresh;
  const _MeldCards(
      {required this.cards,
      required this.theme,
      required this.cardFace,
      required this.fresh});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: t.woodDeep.withValues(alpha: 0.55),
        border: Border.all(
          color: fresh ? t.accentLight : t.accent.withValues(alpha: 0.35),
          width: fresh ? 2.5 : 1.2,
        ),
        boxShadow: [
          if (fresh)
            BoxShadow(
                color: t.accent.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          for (final c in cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: PlayingCard(
                width: 34,
                rank: c.rank,
                suit: c.suit,
                cardFaceStyle: cardFace,
                theme: t,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The active human's hand: face-up, tappable, selected cards lift.
// ---------------------------------------------------------------------------
class _HandStrip extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  final int cardFace;
  final void Function(RummyCard) onToggle;
  const _HandStrip({
    required this.engine,
    required this.theme,
    required this.cardFace,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final seat = engine.activeSeat;
    final hand = List<RummyCard>.of(seat.hand)
      ..sort((a, b) {
        final s = a.suit.compareTo(b.suit);
        return s != 0 ? s : a.rank.compareTo(b.rank);
      });
    final canSelect = engine.phase == RummyPhase.awaitingAction;
    String hint;
    switch (engine.phase) {
      case RummyPhase.awaitingDraw:
        hint = 'Draw from the stock or take the top discard.';
        break;
      case RummyPhase.awaitingAction:
        hint =
            'Tap cards to select, then Meld, Lay off, or Discard one to end your turn.';
        break;
      default:
        hint = '';
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.playerColors[engine.turn],
              ),
            ),
            const SizedBox(width: 8),
            Text('${seat.name}\'s hand',
                style: Felt.label(13, theme: t)),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final c in hand)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: PlayingCard(
                    width: 50,
                    rank: c.rank,
                    suit: c.suit,
                    cardFaceStyle: cardFace,
                    selected: engine.selection.contains(c),
                    theme: t,
                    onTap: canSelect ? () => onToggle(c) : null,
                  ),
                ),
            ],
          ),
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(hint,
              style: Felt.body(13,
                  theme: t, color: t.ivory.withValues(alpha: 0.75)),
              textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

/// Slim strip shown while no human is acting (bot turns, dealing).
class _WaitingStrip extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  const _WaitingStrip({required this.engine, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final label = switch (engine.phase) {
      RummyPhase.dealing => 'Dealing the cards… 🎴',
      RummyPhase.aiTurn => '🤖 ${engine.activeSeat.name} is playing…',
      RummyPhase.idle => 'Getting ready…',
      _ => '…',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: t.woodDeep.withValues(alpha: 0.55),
        border:
            Border.all(color: t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(label, style: Felt.body(14, theme: t)),
    );
  }
}

// ---------------------------------------------------------------------------
// Contextual action buttons.
// ---------------------------------------------------------------------------
class _ActionBar extends StatelessWidget {
  final RummyEngine engine;
  final FeltThemeDef theme;
  final bool canAct;
  final VoidCallback onDrawStock;
  final VoidCallback onDrawDiscard;
  final VoidCallback onMeld;
  final VoidCallback onLayOff;
  final VoidCallback onDiscard;
  final VoidCallback onClear;
  const _ActionBar({
    required this.engine,
    required this.theme,
    required this.canAct,
    required this.onDrawStock,
    required this.onDrawDiscard,
    required this.onMeld,
    required this.onLayOff,
    required this.onDiscard,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (!canAct) return const SizedBox.shrink();
    Widget btn(String label, VoidCallback? onTap, {bool primary = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: onTap == null
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: primary
                            ? [t.accentLight, t.accent, t.accentDark]
                            : [t.woodMid, t.woodDark],
                      ),
                color: onTap == null
                    ? t.woodDeep.withValues(alpha: 0.4)
                    : null,
                border: Border.all(
                  color: onTap == null
                      ? t.accent.withValues(alpha: 0.25)
                      : t.accentLight,
                  width: primary ? 2.5 : 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                label,
                style: Felt.label(14,
                    theme: t,
                    color: onTap == null
                        ? t.ivory.withValues(alpha: 0.35)
                        : (primary ? t.woodDeep : t.ivory)),
              ),
            ),
          ),
        );
    if (engine.phase == RummyPhase.awaitingDraw) {
      return Wrap(
        alignment: WrapAlignment.center,
        children: [
          btn('🎴 Draw Stock', onDrawStock, primary: true),
          btn('♻️ Take Discard',
              engine.discard.isNotEmpty ? onDrawDiscard : null),
        ],
      );
    }
    if (engine.phase == RummyPhase.awaitingAction) {
      final sel = engine.selection;
      final meldOk = RummyEngine.isValidMeld(sel);
      return Wrap(
        alignment: WrapAlignment.center,
        children: [
          btn('✨ Meld${sel.isNotEmpty ? ' (${sel.length})' : ''}',
              meldOk ? onMeld : null,
              primary: meldOk),
          btn('➕ Lay Off', sel.length == 1 ? onLayOff : null),
          btn('🗑️ Discard', sel.length == 1 ? onDiscard : null,
              primary: sel.length == 1),
          if (sel.isNotEmpty) btn('Clear', onClear),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------
// Lay-off target picker.
// ---------------------------------------------------------------------------
class _LayOffSheet extends StatelessWidget {
  final List<({int seat, int meld, List<RummyCard> cards})> targets;
  final RummyEngine engine;
  final FeltThemeDef theme;
  final RummyAudio audio;
  final RummyCard card;
  const _LayOffSheet({
    required this.targets,
    required this.engine,
    required this.theme,
    required this.audio,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.woodMid, t.woodDeep],
        ),
        border: Border.all(color: t.accent, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Lay off ${card.rankLabel}${card.suitLabel} onto…',
              style: Felt.display(19, theme: t)),
          const SizedBox(height: 12),
          for (final tg in targets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  audio.click();
                  Navigator.of(context).pop();
                  engine.layOff(tg.seat, tg.meld);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${engine.seats[tg.seat].name}: ${tg.cards.map((c) => '${c.rankLabel}${c.suitLabel}').join(' ')}',
                    style: Felt.body(15, theme: t),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
            child:
                Text('Cancel', style: Felt.label(14, theme: t)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Round-end dialog.
// ---------------------------------------------------------------------------
class _RoundDialog extends StatelessWidget {
  final RummyEngine engine;
  final RummyAudio audio;
  final FeltThemeDef theme;
  const _RoundDialog(
      {required this.engine, required this.audio, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final w = engine.seats[engine.lastWinner];
    return WajihaDialog(
      theme: t,
      title: '🎴 RUMMY!',
      emoji: '🃏',
      children: [
        Text('${w.name} takes the round!',
            style: Felt.body(16, theme: t), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        for (int i = 0; i < engine.seatCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.playerColors[i],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(engine.seats[i].name,
                        style: Felt.body(14, theme: t))),
                Text('${engine.seats[i].score} deadwood',
                    style: Felt.label(13, theme: t)),
                if (i == engine.lastWinner)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text('👑',
                        style: Felt.body(14, theme: t)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        FeltButton(
          label: 'Next Round',
          width: 220,
          theme: t,
          onTap: () {
            audio.click();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Match-over dialog.
// ---------------------------------------------------------------------------
class _MatchDialog extends StatelessWidget {
  final RummyEngine engine;
  final int winnerIndex;
  final bool humanWon;
  final RummyAudio audio;
  final FeltThemeDef theme;
  const _MatchDialog({
    required this.engine,
    required this.winnerIndex,
    required this.humanWon,
    required this.audio,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final w = engine.seats[winnerIndex];
    final order = List<int>.generate(engine.seatCount, (i) => i)
      ..sort((a, b) => engine.seats[a].score.compareTo(engine.seats[b].score));
    return WajihaDialog(
      theme: t,
      title: humanWon ? 'Victory!' : 'Match Over',
      emoji: '🏆',
      children: [
        Text(
          humanWon
              ? '${w.name} wins the match with just ${w.score} deadwood. The parlor applauds!'
              : '${w.name} takes the crown with ${w.score} deadwood.',
          style: Felt.body(15,
              theme: t, color: t.ivory.withValues(alpha: 0.85)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        for (int rank = 0; rank < order.length; rank++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(['🥇', '🥈', '🥉', '4.'][rank],
                      style: Felt.body(14, theme: t)),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.playerColors[order[rank]],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(engine.seats[order[rank]].name,
                        style: Felt.body(14, theme: t))),
                Text('${engine.seats[order[rank]].score}',
                    style: Felt.label(13, theme: t)),
              ],
            ),
          ),
        const SizedBox(height: 18),
        FeltButton(
          label: 'Play Again',
          width: 220,
          theme: t,
          onTap: () {
            audio.click();
            Navigator.of(context).pop(true);
          },
        ),
        const SizedBox(height: 10),
        FeltButton(
          label: 'Main Menu',
          width: 220,
          fontSize: 16,
          theme: t,
          onTap: () {
            audio.click();
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pause overlay
// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final FeltThemeDef theme;
  final RummyAudio audio;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.audio,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding:
            const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDeep],
          ),
          border: Border.all(color: t.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: Felt.display(28, theme: t)),
            const SizedBox(height: 20),
            FeltButton(
                label: 'Resume',
                width: 220,
                theme: t,
                onTap: onResume),
            const SizedBox(height: 12),
            FeltButton(
                label: 'Restart Round',
                width: 220,
                theme: t,
                onTap: onRestart),
            const SizedBox(height: 12),
            FeltButton(
                label: 'Quit to Menu',
                width: 220,
                theme: t,
                onTap: onQuit),
          ],
        ),
      ),
    );
  }
}
