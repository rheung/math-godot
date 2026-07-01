# Math Game

A mobile-first Godot math game for kids.

## Overview

- 3x3 answer grid with touch input
- Randomized math questions with one correct answer and distractors
- Score + streak system with combo bonuses
- Level-based difficulty progression
- Timed rounds with countdown sounds and urgency feedback
- Welcome, Options, and Help screens

## Gameplay Rules

- Tap the correct answer before time runs out.
- Correct answer: +1 point.
- Combo bonus: every 3rd correct in a streak grants +2 bonus points.
- Wrong answer or timeout: lose 1 chance.
- Game ends when chances reach 0.

## Power-Ups

Power-ups are optional and can be shown/hidden from Options.

- Hint: disables two wrong answers
- +2s: adds 2 seconds to the current question
- Shield: protects against one wrong answer or timeout

## Progression

- Difficulty increases with level.
- Operations progress from basic to mixed expressions.
- Questions per level is configurable in Options.
- Default questions per level: 10.

## Menus

- Welcome screen: Start Game, Options, Help
- Options screen:
  - Show Assist Items toggle
  - Questions Per Level setting
- Help screen:
  - Multi-page quick instructions

## Project Structure

- Main scene: `scenes/main.tscn`
- Main game script: `scripts/math_game.gd`

## Run

1. Open the project in Godot 4.7+.
2. Run the project (`project.godot` main scene is configured).

## Web Export

A web export build is included under `docs/`.
