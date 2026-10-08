import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const RummyApp());

class RummyApp extends StatelessWidget {
  const RummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.candyShop,
      title: 'Rummy',
      tagline: 'Meld sneaky sets, drop slick runs, and shout RUMMY before your rivals do!',
      emoji: '🎴',
      slug: 'rummy',
      howToPlay:
          '• You get 7 cards. Draw from the stock or snatch the top discard.\n• Meld SETS (3-4 of a kind) or RUNS (3+ in sequence, same suit).\n• Discard one card to end your turn.\n• Empty your hand to yell RUMMY! Rivals score their leftovers.\n• Lowest total after 3 rounds takes the crown. 👑',
      playerOptions: const [1, 2, 3, 4],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => RummyScreen(players: players, callbacks: cb),
    );
  }
}
