-- ====================================================================
-- DATABASE SCHEMA: johen_gaming
-- Sistem Admin & Rekapitulasi: Rekap Chat, Rekap Sold, Transaksi, & Staff
-- Dibuat untuk: Laragon (MySQL / MariaDB) via phpMyAdmin
-- Karakteristik: Support 0 di awal nomor WA (VARCHAR), kalkulasi otomatis
-- ====================================================================

CREATE DATABASE IF NOT EXISTS `johen_gaming` 
DEFAULT CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `johen_gaming`;

-- Matikan foreign key check sementara saat migrasi
SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS `v_rekap_chat_harian`;
DROP VIEW IF EXISTS `v_ringkasan_penjualan_game`;
DROP VIEW IF EXISTS `v_performa_sub_pic`;
DROP TABLE IF EXISTS `riwayat_aktivitas`;
DROP TABLE IF EXISTS `transaksi_proses`;
DROP TABLE IF EXISTS `rekap_sold`;
DROP TABLE IF EXISTS `rekap_chat`;
DROP TABLE IF EXISTS `master_store_game`;
DROP TABLE IF EXISTS `users`;
SET FOREIGN_KEY_CHECKS = 1;


-- --------------------------------------------------------------------
-- 1. TABEL USERS / STAFF ADMIN & PIC
-- Digunakan untuk login, autentikasi, serta PIC/Admin penanggung jawab
-- --------------------------------------------------------------------
CREATE TABLE `users` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `username` VARCHAR(50) NOT NULL UNIQUE,
  `nama_lengkap` VARCHAR(100) NOT NULL,
  `email` VARCHAR(100) DEFAULT NULL,
  `password` VARCHAR(255) NOT NULL,
  `role` ENUM('superadmin', 'admin', 'pic', 'sub_pic', 'staff') NOT NULL DEFAULT 'staff',
  `shift_default` ENUM('Pagi', 'Malam') DEFAULT 'Pagi',
  `no_hp` VARCHAR(25) DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- --------------------------------------------------------------------
-- 2. TABEL MASTER STORE GAME
-- Menyimpan katalog game yang ada di Johen Gaming
-- Sesuai dropdown form: Free Fire, Mobile Legend, PUBG, Valorant, dll.
-- --------------------------------------------------------------------
CREATE TABLE `master_store_game` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `kode_store` VARCHAR(30) NOT NULL UNIQUE,
  `nama_store` VARCHAR(100) NOT NULL,
  `deskripsi` VARCHAR(255) DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- --------------------------------------------------------------------
-- 3. TABEL REKAP CHAT (LEAD TRACKER CS)
-- Digunakan untuk menyimpan data dari form: form-chat.html
-- Status: Closing, Follow Up, Ghosting
-- Catatan No WA: Menggunakan VARCHAR(25) agar angka awalan '0' tidak hilang
-- --------------------------------------------------------------------
CREATE TABLE `rekap_chat` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `tanggal` DATE NOT NULL,
  `shift` ENUM('Pagi', 'Malam') NOT NULL DEFAULT 'Pagi',
  `no_wa` VARCHAR(25) NOT NULL,
  `status` ENUM('Closing', 'Follow Up', 'Ghosting') NOT NULL,
  `admin_id` INT UNSIGNED DEFAULT NULL,
  `catatan` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_rekap_chat_tanggal` (`tanggal`),
  INDEX `idx_rekap_chat_shift` (`shift`),
  INDEX `idx_rekap_chat_status` (`status`),
  CONSTRAINT `fk_rekap_chat_user` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- --------------------------------------------------------------------
-- 4. TABEL REKAP SOLD (PENJUALAN AKUN GAME)
-- Sesuai 13 kolom di form-sold.html:
-- NO · TGL MASUK · TGL TERJUAL · STATUS · NICKNAME · SPEK · BANK · HARGA AKUN · HARGA TERJUAL · SUB PIC · PIC · ADMIN · NO BUYER
-- Profit dihitung otomatis (harga_terjual - harga_akun)
-- --------------------------------------------------------------------
CREATE TABLE `rekap_sold` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `store_game` VARCHAR(60) NOT NULL,
  `tanggal_masuk` DATE NOT NULL,
  `tanggal_terjual` DATE DEFAULT NULL,
  `status` ENUM('sold', 'available', 'booked') NOT NULL DEFAULT 'sold',
  `nickname` VARCHAR(100) NOT NULL,
  `spek` TEXT DEFAULT NULL,
  `bank` VARCHAR(30) NOT NULL,
  `harga_akun` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT 'Harga Akun (Nilai Listing / Pasang Awal)',
  `harga_terjual` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT 'Harga Laku / Terjual (Setelah Open Nego & Diskon)',
  `potongan_nego` DECIMAL(12, 2) GENERATED ALWAYS AS (`harga_akun` - `harga_terjual`) STORED COMMENT 'Penurunan Harga Nego & Diskon',
  `sub_pic` VARCHAR(100) DEFAULT NULL,
  `pic` VARCHAR(100) DEFAULT NULL,
  `admin` VARCHAR(100) DEFAULT NULL,
  `no_buyer` VARCHAR(25) DEFAULT NULL COMMENT 'No WA/Kontak Pembeli (disimpan string agar 0 tidak hilang)',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_rekap_sold_store` (`store_game`),
  INDEX `idx_rekap_sold_tgl_terjual` (`tanggal_terjual`),
  INDEX `idx_rekap_sold_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- --------------------------------------------------------------------
-- 5. TABEL TRANSAKSI PROSES (PIPELINE OPERASIONAL ADMIN)
-- Sesuai input-transaksi.html / form_transaksi.html
-- Status Proses: checking -> secured -> done (atau canceled)
-- --------------------------------------------------------------------
CREATE TABLE `transaksi_proses` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `id_transaksi` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Contoh: TRX-20261005-001',
  `nama_staf_admin` VARCHAR(100) NOT NULL,
  `user_id` INT UNSIGNED DEFAULT NULL,
  `kategori_store` VARCHAR(60) NOT NULL,
  `catatan_akun` TEXT DEFAULT NULL,
  `nominal` DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
  `status_proses` ENUM('checking', 'secured', 'done', 'canceled') NOT NULL DEFAULT 'checking',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_transaksi_status` (`status_proses`),
  INDEX `idx_transaksi_store` (`kategori_store`),
  CONSTRAINT `fk_transaksi_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- --------------------------------------------------------------------
-- 6. TABEL RIWAYAT AKTIVITAS (AUDIT LOG)
-- Mencatat aktivitas penting staf/admin untuk transparansi sistem
-- --------------------------------------------------------------------
CREATE TABLE `riwayat_aktivitas` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED DEFAULT NULL,
  `modul` VARCHAR(50) NOT NULL COMMENT 'rekap_chat, rekap_sold, transaksi',
  `aksi` VARCHAR(50) NOT NULL COMMENT 'insert, update, delete',
  `deskripsi` TEXT NOT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_log_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ====================================================================
-- VIEWS: KALKULASI OTOMATIS (REALTIME)
-- Menghitung akumulasi Total Lead, Closing Rate, dan Omset secara otomatis
-- ====================================================================

-- View 1: Akumulasi Rekap Chat per Tanggal & Shift
-- Rumus: Total Lead = Closing + Ghosting + Follow Up
-- Closing Rate = (Closing / Total Lead) * 100%
CREATE OR REPLACE VIEW `v_rekap_chat_harian` AS
SELECT 
  `tanggal`,
  `shift`,
  SUM(CASE WHEN `status` = 'Closing' THEN 1 ELSE 0 END) AS `total_closing`,
  SUM(CASE WHEN `status` = 'Follow Up' THEN 1 ELSE 0 END) AS `total_follow_up`,
  SUM(CASE WHEN `status` = 'Ghosting' THEN 1 ELSE 0 END) AS `total_ghosting`,
  COUNT(*) AS `total_lead`,
  ROUND(
    (SUM(CASE WHEN `status` = 'Closing' THEN 1 ELSE 0 END) / COUNT(*)) * 100, 
    2
  ) AS `closing_rate_persen`
FROM `rekap_chat`
GROUP BY `tanggal`, `shift`;

-- View 2: Ringkasan Penjualan per Game Store
CREATE OR REPLACE VIEW `v_ringkasan_penjualan_game` AS
SELECT 
  `store_game`,
  COUNT(*) AS `total_akun_terjual`,
  SUM(`harga_akun`) AS `total_harga_akun`,
  SUM(`harga_terjual`) AS `total_harga_laku`
FROM `rekap_sold`
WHERE `status` = 'sold'
GROUP BY `store_game`;

-- View 3: Rekap Performa Penjualan per Sub PIC & PIC (Host Live, Saluran, IG, dll.)
CREATE OR REPLACE VIEW `v_performa_sub_pic` AS
SELECT 
  COALESCE(`sub_pic`, 'Lainnya') AS `sub_pic`,
  COALESCE(`pic`, '-') AS `pic`,
  COUNT(*) AS `total_akun_terjual`,
  SUM(`harga_terjual`) AS `total_omset_laku`
FROM `rekap_sold`
WHERE `status` = 'sold'
GROUP BY `sub_pic`, `pic`;


-- ====================================================================
-- DATA AWAL / SAMPLE DATA (DUMMY DATA)
-- Agar setelah di-import langsung bisa dicek di phpMyAdmin
-- ====================================================================

-- 1. Sample User / Staff
INSERT INTO `users` (`id`, `username`, `nama_lengkap`, `email`, `password`, `role`, `shift_default`, `no_hp`) VALUES
(1, 'superadmin', 'Super Administrator', 'admin@johengaming.com', '$2y$10$abcdefghijklmnopqrstuvwxyz1234567890', 'superadmin', 'Pagi', '081234567890'),
(2, 'admin_pagi', 'Staf Admin 1 (Pagi)', 'staf1@johengaming.com', '$2y$10$abcdefghijklmnopqrstuvwxyz1234567890', 'staff', 'Pagi', '081298765432'),
(3, 'admin_malam', 'Staf Admin 2 (Malam)', 'staf2@johengaming.com', '$2y$10$abcdefghijklmnopqrstuvwxyz1234567890', 'staff', 'Malam', '085712345678');

-- 2. Sample Master Store Game
INSERT INTO `master_store_game` (`kode_store`, `nama_store`, `deskripsi`) VALUES
('FF', 'Free Fire', 'Store Akun Free Fire'),
('ML', 'Mobile Legend', 'Store Akun Mobile Legends: Bang Bang'),
('JP', 'Johen PUBG', 'Store Akun PUBG Mobile Johen'),
('MP', 'Monkey PUBG', 'Store Akun PUBG Mobile Monkey'),
('VL', 'Valorant', 'Store Akun Riot Games Valorant'),
('EF', 'EFootball', 'Store Akun Konami eFootball'),
('FC', 'FC Mobile', 'Store Akun EA Sports FC Mobile'),
('RB', 'Roblox', 'Store Akun Roblox');

-- 3. Sample Rekap Chat (Perhatikan format '08...' tetap utuh karena VARCHAR)
INSERT INTO `rekap_chat` (`tanggal`, `shift`, `no_wa`, `status`, `admin_id`) VALUES
(CURDATE(), 'Pagi', '088123456789', 'Closing', 2),
(CURDATE(), 'Pagi', '088987654321', 'Follow Up', 2),
(CURDATE(), 'Pagi', '081399887766', 'Ghosting', 2),
(CURDATE(), 'Pagi', '087722334455', 'Closing', 2),
(CURDATE(), 'Malam', '085611223344', 'Follow Up', 3),
(CURDATE(), 'Malam', '089600112233', 'Ghosting', 3);

-- 4. Sample Rekap Sold (Harga Akun vs Harga Laku/Terjual setelah Nego)
INSERT INTO `rekap_sold` 
(`store_game`, `tanggal_masuk`, `tanggal_terjual`, `status`, `nickname`, `spek`, `bank`, `harga_akun`, `harga_terjual`, `sub_pic`, `pic`, `admin`, `no_buyer`) 
VALUES
('Mobile Legend', CURDATE() - INTERVAL 2 DAY, CURDATE(), 'sold', 'SultanML99', 'Rank Mythic, Skin Collector 3, WR 65%', 'QRIS', 500000.00, 450000.00, 'Sub-PIC ML', 'PIC Utama', 'Staf Admin 1', '088212345678'),
('Free Fire', CURDATE() - INTERVAL 1 DAY, CURDATE(), 'sold', 'RajaHeadshot', 'Old Season 2, Bundle Hip Hop, MP40 Cobra', 'BRI', 650000.00, 580000.00, 'Sub-PIC FF', 'PIC Utama', 'Staf Admin 1', '081299008877'),
('Valorant', CURDATE(), NULL, 'available', 'JettMain#ID1', 'Vandal Prime, Phantom Oni, Rank Diamond 2', 'QRIS', 250000.00, 0.00, 'Sub-PIC VL', 'PIC Utama', 'Staf Admin 2', NULL);

-- 5. Sample Transaksi Proses
INSERT INTO `transaksi_proses` (`id_transaksi`, `nama_staf_admin`, `user_id`, `kategori_store`, `catatan_akun`, `nominal`, `status_proses`) VALUES
('TRX-20261005-001', 'Staf Admin 1', 2, 'Mobile Legend', 'Akun Mythic SultanML99', 450000.00, 'done'),
('TRX-20261005-002', 'Staf Admin 1', 2, 'Free Fire', 'Akun Old S2 RajaHeadshot', 580000.00, 'secured'),
('TRX-20261005-003', 'Staf Admin 2', 3, 'Valorant', 'Akun Vandal Prime', 250000.00, 'checking');
