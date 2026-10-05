/**
 * buat-jembatan-excel.js
 * Jalankan: node buat-jembatan-excel.js
 * Menghasilkan dua file .txt berisi kode Google Apps Script
 * yang siap disalin ke editor Apps Script Google Sheets.
 */

import fs   from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// ─────────────────────────────────────────────────────────────────────────────
// 1. Script_Rekap_Chat.txt
//    Sheet: Rekap Chat
//    Header di Baris 3 → data mulai Baris 4
//    Kolom: A=NO | B=TANGGAL | C=SHIFT | D=NO WA | E=STATUS | F=PERSENAN REKAP CHAT
// ─────────────────────────────────────────────────────────────────────────────
const scriptRekapChat = `// ============================================================
//  Google Apps Script — Rekap Chat
//  Salin seluruh kode ini ke Apps Script editor Google Sheets
//  Sheet target : tab aktif (Rekap Chat)
//  Header       : Baris 3
//  Data masuk   : Baris 4 ke bawah
// ============================================================

function doPost(e) {
  try {
    var data   = JSON.parse(e.postData.contents);
    var sheet  = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();

    // Tentukan baris terakhir yang berisi data (mulai hitung dari baris 3)
    var lastRow = sheet.getLastRow();

    // Nomor urut: jika belum ada data (lastRow <= 3), mulai dari 1
    // Jika sudah ada data, hitung (lastRow - 2) karena baris 1-2 bukan data
    var nomorUrut = (lastRow > 3) ? (lastRow - 2) + 1 : 1;

    // Baris tujuan penulisan data baru
    var targetRow = (lastRow < 4) ? 4 : lastRow + 1;

    // Format persentase — tambahkan simbol % jika belum ada
    var persenan = String(data.persenan_rekap_chat || '0');
    if (persenan.indexOf('%') === -1) {
      persenan = persenan + '%';
    }

    // Tulis data ke baris target
    // Urutan kolom: A=NO | B=TANGGAL | C=SHIFT | D=NO WA | E=STATUS | F=PERSENAN REKAP CHAT
    sheet.getRange(targetRow, 1, 1, 6).setValues([[
      nomorUrut,
      data.tanggal    || new Date().toLocaleDateString('id-ID'),
      data.shift      || '',
      data.no_wa      || '',
      data.status     || '',
      persenan
    ]]);

    return ContentService
      .createTextOutput(JSON.stringify({ status: 'ok', row: targetRow, no: nomorUrut }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: 'error', message: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// ── Fungsi pengujian manual dari editor Apps Script ──────────────────────────
// Klik Run pada fungsi ini untuk menguji tanpa deploy
function testDoPost() {
  var fakeEvent = {
    postData: {
      contents: JSON.stringify({
        tanggal            : '01/07/2025',
        shift              : 'Pagi',
        no_wa              : '08123456789',
        status             : 'Aktif',
        persenan_rekap_chat: '85'
      })
    }
  };
  var result = doPost(fakeEvent);
  Logger.log(result.getContent());
}
`;

// ─────────────────────────────────────────────────────────────────────────────
// 2. Script_Rekap_Sold.txt
//    Sheet: dipilih otomatis berdasarkan properti 'store_game'
//    Header di Baris 3 → data mulai Baris 4 (Baris 1-2 = rumus kalkulasi)
//    Kolom: A=NO | B=TANGGAL MASUK | C=TANGGAL TERJUAL | D=STATUS |
//           E=NICKNAME | F=SPEK | G=BANK | H=HARGA AKUN | I=HARGA TERJUAL |
//           J=SUB PIC | K=PIC | L=ADMIN | M=NOMOR BUYER
// ─────────────────────────────────────────────────────────────────────────────
const scriptRekapSold = `// ============================================================
//  Google Apps Script — Rekap Sold (8 Store Game)
//  Salin seluruh kode ini ke Apps Script editor Google Sheets
//  Sheet target : dipilih otomatis dari properti 'store_game'
//  Baris 1-2    : rumus kalkulasi otomatis (JANGAN disentuh)
//  Header       : Baris 3
//  Data masuk   : Baris 4 ke bawah
// ============================================================

// Peta nama store dari web → nama tab sheet di Google Sheets
// Sesuaikan nilai kanan jika nama tab Anda berbeda
var STORE_SHEET_MAP = {
  'Free Fire'    : 'Free Fire',
  'Mobile Legend': 'Mobile Legend',
  'Johen PUBG'   : 'Johen PUBG',
  'Monkey PUBG'  : 'Monkey PUBG',
  'Valorant'     : 'Valorant',
  'EFootball'    : 'EFootball',
  'FC Mobile'    : 'FC Mobile',
  'Roblox'       : 'Roblox'
};

function doPost(e) {
  try {
    var data      = JSON.parse(e.postData.contents);
    var storeGame = data.store_game || '';

    // Cari nama tab sheet yang sesuai
    var sheetName = STORE_SHEET_MAP[storeGame];
    if (!sheetName) {
      return ContentService
        .createTextOutput(JSON.stringify({
          status : 'error',
          message: 'store_game tidak dikenali: ' + storeGame
        }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    var ss    = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      return ContentService
        .createTextOutput(JSON.stringify({
          status : 'error',
          message: 'Sheet tidak ditemukan: ' + sheetName
        }))
        .setMimeType(ContentService.MimeType.JSON);
    }

    // Baris 1-2 = rumus kalkulasi → data dimulai dari baris 4
    // lastRow bisa mengembalikan 1 atau 2 jika hanya rumus yang ada
    var lastRow   = sheet.getLastRow();
    var targetRow = (lastRow < 4) ? 4 : lastRow + 1;

    // Nomor urut: hitung dari baris 4 ke bawah
    var nomorUrut = targetRow - 3;  // baris 4 = no.1, baris 5 = no.2, dst.

    // Kolom D (STATUS) selalu diisi 'sold' secara otomatis
    var statusSold = 'sold';

    // Tulis 13 kolom sekaligus
    // A=NO | B=TANGGAL MASUK | C=TANGGAL TERJUAL | D=STATUS |
    // E=NICKNAME | F=SPEK | G=BANK | H=HARGA AKUN | I=HARGA TERJUAL |
    // J=SUB PIC | K=PIC | L=ADMIN | M=NOMOR BUYER
    sheet.getRange(targetRow, 1, 1, 13).setValues([[
      nomorUrut,
      data.tanggal_masuk    || new Date().toLocaleDateString('id-ID'),
      data.tanggal_terjual  || '',
      statusSold,
      data.nickname         || '',
      data.spek             || '',
      data.bank             || '',
      data.harga_akun       || 0,
      data.harga_terjual    || 0,
      data.sub_pic          || '',
      data.pic              || '',
      data.admin            || '',   // nama staf penginput dari web
      data.nomor_buyer      || ''
    ]]);

    return ContentService
      .createTextOutput(JSON.stringify({
        status   : 'ok',
        sheet    : sheetName,
        row      : targetRow,
        no       : nomorUrut
      }))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: 'error', message: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

// ── Fungsi pengujian manual dari editor Apps Script ──────────────────────────
// Klik Run pada fungsi ini untuk menguji tanpa deploy
function testDoPost() {
  var fakeEvent = {
    postData: {
      contents: JSON.stringify({
        store_game      : 'Free Fire',
        tanggal_masuk   : '01/07/2025',
        tanggal_terjual : '02/07/2025',
        nickname        : 'PlayerXYZ',
        spek            : 'Rank Diamond, Hero 120, Skin Rare',
        bank            : 'BCA',
        harga_akun      : 500000,
        harga_terjual   : 450000,
        sub_pic         : 'Koord1',
        pic             : 'Koordinator 1',
        admin           : 'Staf Admin 3',
        nomor_buyer     : '08987654321'
      })
    }
  };
  var result = doPost(fakeEvent);
  Logger.log(result.getContent());
}
`;

// ─────────────────────────────────────────────────────────────────────────────
// Tulis kedua file ke folder yang sama dengan script ini
// ─────────────────────────────────────────────────────────────────────────────
const outDir = __dirname;

const files = [
  { name: 'Script_Rekap_Chat.txt', content: scriptRekapChat },
  { name: 'Script_Rekap_Sold.txt', content: scriptRekapSold },
];

files.forEach(({ name, content }) => {
  const filePath = path.join(outDir, name);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`✅  Berhasil dibuat: ${filePath}`);
});

console.log('\n📋  Cara pakai:');
console.log('   1. Buka Google Sheets Anda');
console.log('   2. Klik Extensions → Apps Script');
console.log('   3. Hapus kode default, salin isi file .txt yang sesuai');
console.log('   4. Klik Deploy → New deployment → Web App');
console.log('      - Execute as : Me');
console.log('      - Who has access : Anyone');
console.log('   5. Salin URL deployment ke variabel SPREADSHEET_API_URL');
console.log('      di production/input-transaksi.html\n');
