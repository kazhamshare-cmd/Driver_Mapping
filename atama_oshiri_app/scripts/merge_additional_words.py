#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
additional_words.jsonの内容を既存の辞書ファイルにマージするスクリプト
"""

import json
import os
from collections import defaultdict

def load_additional_words(filepath):
    """additional_words.jsonを読み込む"""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 全カテゴリの単語を統合
    all_words = []
    for category, words in data.items():
        all_words.extend(words)

    return all_words

def group_by_first_char(words):
    """単語を最初の文字でグループ化"""
    grouped = defaultdict(list)
    for word in words:
        if word:
            first_char = word[0]
            grouped[first_char].append(word)
    return grouped

def load_existing_dict(filepath):
    """既存の辞書ファイルを読み込む"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        return []

def save_dict(filepath, words):
    """辞書ファイルを保存"""
    # 重複を除去してソート
    unique_words = sorted(set(words))

    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(unique_words, f, ensure_ascii=False, indent=2)

def main():
    # パスの設定
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dict_dir = os.path.join(os.path.dirname(script_dir), 'assets', 'dictionary')
    additional_file = os.path.join(dict_dir, 'additional_words.json')

    print(f"辞書ディレクトリ: {dict_dir}")
    print(f"追加単語ファイル: {additional_file}")

    # 追加単語を読み込む
    additional_words = load_additional_words(additional_file)
    print(f"\n追加する単語数: {len(additional_words)}個")

    # 文字ごとにグループ化
    grouped = group_by_first_char(additional_words)
    print(f"文字の種類: {len(grouped)}種類")

    # 各文字ごとに処理
    total_added = 0
    for char, new_words in sorted(grouped.items()):
        dict_file = os.path.join(dict_dir, f'char_{char}.json')

        # 既存の辞書を読み込む
        existing_words = load_existing_dict(dict_file)
        original_count = len(existing_words)

        # 新しい単語を追加
        combined_words = existing_words + new_words

        # 保存
        save_dict(dict_file, combined_words)

        # 結果を表示
        new_count = len(set(combined_words))
        added_count = new_count - original_count
        total_added += added_count

        print(f"{char}: {original_count}個 → {new_count}個 (+{added_count}個)")

    print(f"\n合計 {total_added}個の新しい単語を追加しました")

if __name__ == "__main__":
    main()
