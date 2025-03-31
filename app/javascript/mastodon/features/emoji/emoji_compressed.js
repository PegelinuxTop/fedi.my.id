// @preval
// http://www.unicode.org/Public/emoji/5.0/emoji-test.txt
// This file contains the compressed version of the emoji data from
// both emoji_map.json and from emoji-mart's emojiIndex and data objects.
// It's designed to be emitted in an array format to take up less space
// over the wire.

// This version comment should be bumped each time the emoji data is changed
// to ensure that the prevaled file is regenerated by Babel
// version: 4

// This json file contains the names of the categories.
const emojiMart5LocalesData = require('@emoji-mart/data/i18n/en.json');
const { uncompress: emojiMartUncompress } = require('emoji-mart/dist/utils/data');
const _ = require('lodash');


const emojiMart5Data = require('./emoji_all.json');
const emojiMap = require('./emoji_map.json');
// This json file is downloaded from https://github.com/iamcal/emoji-data/
// and is used to correct the sheet coordinates since we're using that repo's sheet
const emojiSheetData = require('./emoji_sheet.json');
const { unicodeToFilename } = require('./unicode_to_filename');
const { unicodeToUnifiedName } = require('./unicode_to_unified_name');

// Grabbed from `emoji_utils` to avoid circular dependency
function unifiedToNative(unified) {
  let unicodes = unified.split('-'),
    codePoints = unicodes.map((u) => `0x${u}`);

  return String.fromCodePoint(...codePoints);
}

let data = {
  compressed: true,
  categories: emojiMart5Data.categories.map(cat => {
    return {
      ...cat,
      name: emojiMart5LocalesData.categories[cat.id]
    };
  }),
  aliases: emojiMart5Data.aliases,
  emojis: _(emojiMart5Data.emojis).values().map(emoji => {
    let skin_variations = {};
    const unified = emoji.skins[0].unified.toUpperCase();
    const emojiFromRawData = emojiSheetData.find(e => e.unified === unified);

    if (!emojiFromRawData) {
      return undefined;
    }

    if (emoji.skins.length > 1) {
      const [, ...nonDefaultSkins] = emoji.skins;
      nonDefaultSkins.forEach(skin => {
        const [matchingRawCodePoints,matchingRawEmoji] = Object.entries(emojiFromRawData.skin_variations).find((pair) => {
          const [, value] = pair;
          return value.unified.toLowerCase() === skin.unified;
        });

        if (matchingRawEmoji && matchingRawCodePoints) {
          // At the time of writing, the json from `@emoji-mart/data` doesn't have data
          // for emoji like `woman-heart-woman` with two different skin tones.
          const skinToneCode = matchingRawCodePoints.split('-')[0];
          skin_variations[skinToneCode] = {
            unified: matchingRawEmoji.unified.toUpperCase(),
            non_qualified: null,
            sheet_x: matchingRawEmoji.sheet_x,
            sheet_y: matchingRawEmoji.sheet_y,
            has_img_twitter: true,
            native: unifiedToNative(matchingRawEmoji.unified.toUpperCase())
          };
        }
      });
    }

    return {
      a: emoji.name,
      b: unified,
      c: undefined,
      f: true,
      j: [emoji.id, ...emoji.keywords],
      k: [emojiFromRawData.sheet_x, emojiFromRawData.sheet_y],
      m: emoji.emoticons?.[0],
      l: emoji.emoticons,
      o: emoji.version,
      id: emoji.id,
      skin_variations,
      native: unifiedToNative(unified.toUpperCase())
    };
  }).compact().keyBy(e => e.id).mapValues(e => _.omit(e, 'id')).value()
};

if (data.compressed) {
  emojiMartUncompress(data);
}

const emojiMartData = data;

const excluded       = ['®', '©', '™'];
const skinTones      = ['🏻', '🏼', '🏽', '🏾', '🏿'];
const shortcodeMap   = {};

const shortCodesToEmojiData = {};
const emojisWithoutShortCodes = [];

Object.keys(emojiMart5Data.emojis).forEach(key => {
  let emoji = emojiMart5Data.emojis[key];

  shortcodeMap[emoji.skins[0].native] = emoji.id;
});

const stripModifiers = unicode => {
  skinTones.forEach(tone => {
    unicode = unicode.replace(tone, '');
  });

  return unicode;
};

Object.keys(emojiMap).forEach(key => {
  if (excluded.includes(key)) {
    delete emojiMap[key];
    return;
  }

  const normalizedKey = stripModifiers(key);
  let shortcode       = shortcodeMap[normalizedKey];

  if (!shortcode) {
    shortcode = shortcodeMap[normalizedKey + '\uFE0F'];
  }

  const filename = emojiMap[key];

  const filenameData = [key];

  if (unicodeToFilename(key) !== filename) {
    // filename can't be derived using unicodeToFilename
    filenameData.push(filename);
  }

  if (typeof shortcode === 'undefined') {
    emojisWithoutShortCodes.push(filenameData);
  } else {
    if (!Array.isArray(shortCodesToEmojiData[shortcode])) {
      shortCodesToEmojiData[shortcode] = [[]];
    }

    shortCodesToEmojiData[shortcode][0].push(filenameData);
  }
});

Object.keys(emojiMartData.emojis).forEach(key => {
  let emoji = emojiMartData.emojis[key];


  const { native } = emoji;
  let { short_names, search, unified } = emojiMartData.emojis[key];

  if (short_names[0] !== key) {
    throw new Error('The compressor expects the first short_code to be the ' +
      'key. It may need to be rewritten if the emoji change such that this ' +
      'is no longer the case.');
  }

  short_names = short_names.slice(1); // first short name can be inferred from the key

  const searchData = [native, short_names, search];

  if (unicodeToUnifiedName(native) !== unified) {
    // unified name can't be derived from unicodeToUnifiedName
    searchData.push(unified);
  }

  if (!Array.isArray(shortCodesToEmojiData[key])) {
    shortCodesToEmojiData[key] = [[]];
  }

  shortCodesToEmojiData[key].push(searchData);
});

// JSON.parse/stringify is to emulate what @preval is doing and avoid any
// inconsistent behavior in dev mode
module.exports = JSON.parse(JSON.stringify([
  shortCodesToEmojiData,
  /*
   * The property `skins` is not found in the current context.
   * This could potentially lead to issues when interacting with modules or data structures
   * that expect the presence of `skins` property.
   * Currently, no definitions or references to `skins` property can be found in:
   * - {@link node_modules/emoji-mart/dist/utils/data.js}
   * - {@link node_modules/emoji-mart/data/all.json}
   * - {@link app/javascript/mastodon/features/emoji/emoji_compressed.d.ts#Skins}
   * Future refactorings or updates should consider adding definitions or handling for `skins` property.
   */
  emojiMartData.skins,
  emojiMartData.categories,
  emojiMartData.aliases,
  emojisWithoutShortCodes,
  emojiMartData
]));
