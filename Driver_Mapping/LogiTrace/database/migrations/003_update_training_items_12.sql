-- Migration 003: Update training_type_master to include all 12 mandatory education items
-- Based on 貨物自動車運送事業法施行規則 第10条
-- Date: 2026-01-16

-- Clear existing data
DELETE FROM training_type_master;

-- Insert all 12 mandatory education items
INSERT INTO training_type_master (code, name_ja, name_en, description, is_mandatory, frequency_months, display_order) VALUES
-- 1. 事業用自動車を運転する場合の心構え
('mindset', '事業用自動車を運転する場合の心構え', 'Driver Mindset for Commercial Vehicles',
 'プロドライバーとしての自覚、責任感、安全運転の重要性を理解する', TRUE, 12, 1),

-- 2. 事業用自動車の運行の安全を確保するために遵守すべき基本的事項
('basic_safety', '事業用自動車の運行の安全確保のための基本的事項', 'Basic Safety Compliance',
 '法令遵守、点呼、日常点検、運行前後の確認事項を理解する', TRUE, 12, 2),

-- 3. 事業用自動車の構造上の特性
('vehicle_characteristics', '事業用自動車の構造上の特性', 'Vehicle Structural Characteristics',
 '車両の構造、死角、内輪差、制動距離、車両感覚を理解する', TRUE, 12, 3),

-- 4. 貨物の正しい積載方法
('cargo_loading', '貨物の正しい積載方法', 'Proper Cargo Loading Methods',
 '積載方法、固縛方法、重心位置、バランスの重要性を理解する', TRUE, 12, 4),

-- 5. 過積載の危険性
('overloading_danger', '過積載の危険性', 'Dangers of Overloading',
 '過積載による車両への影響、事故リスク、法的責任を理解する', TRUE, 12, 5),

-- 6. 危険物を運搬する場合に留意すべき事項
('hazmat_transport', '危険物を運搬する場合に留意すべき事項', 'Hazardous Materials Transport Considerations',
 '危険物の種類、取扱方法、緊急時対応、関連法規を理解する', TRUE, 12, 6),

-- 7. 適切な運行の経路及び当該経路における道路及び交通の状況
('route_planning', '適切な運行経路と道路・交通状況', 'Route Planning and Traffic Conditions',
 '経路選定、道路状況の確認、気象情報の活用を理解する', TRUE, 12, 7),

-- 8. 危険の予測及び回避並びに緊急時における対応方法
('danger_prediction', '危険の予測及び回避と緊急時対応', 'Danger Prediction, Avoidance and Emergency Response',
 '危険予測、防衛運転、緊急時の対応手順を理解する', TRUE, 12, 8),

-- 9. 運転者の運転適性に応じた安全運転
('driver_aptitude', '運転者の運転適性に応じた安全運転', 'Safe Driving Based on Driver Aptitude',
 '自己の運転特性、適性診断結果の活用、弱点の克服を理解する', TRUE, 12, 9),

-- 10. 交通事故に関わる運転者の生理的及び心理的要因及びこれらへの対処方法
('physiological_factors', '交通事故に関わる生理的・心理的要因への対処', 'Physiological and Psychological Factors',
 '疲労、眠気、心理状態が運転に与える影響と対処法を理解する', TRUE, 12, 10),

-- 11. 健康管理の重要性
('health_management', '健康管理の重要性', 'Importance of Health Management',
 '健康診断、日常の健康管理、睡眠、食事、運動の重要性を理解する', TRUE, 12, 11),

-- 12. 安全性の向上を図るための装置を備える事業用自動車の適切な運転方法
('safety_devices', '安全装置を備えた車両の適切な運転方法', 'Proper Operation of Safety-Equipped Vehicles',
 'ドライブレコーダー、デジタコ、衝突被害軽減ブレーキ等の活用を理解する', TRUE, 12, 12);

-- Add industry-specific training types (optional)
INSERT INTO training_type_master (code, name_ja, name_en, description, is_mandatory, frequency_months, display_order) VALUES
-- タクシー・バス向け
('passenger_service', '接客・旅客サービス', 'Passenger Service',
 'タクシー・バス向け：接客マナー、乗降介助、苦情対応を理解する', FALSE, NULL, 101),

-- バス向け
('evacuation_guidance', '避難誘導', 'Evacuation Guidance',
 'バス向け：緊急時の乗客避難誘導手順を理解する', FALSE, NULL, 102),

-- 初任運転者向け特別教育
('initial_training', '初任運転者教育', 'Initial Driver Training',
 '新規採用ドライバー向けの集中教育（15時間以上）', TRUE, NULL, 201),

-- 事故惹起者向け特別教育
('post_accident', '事故惹起者教育', 'Post-Accident Training',
 '事故を起こしたドライバー向けの再教育（6時間以上）', TRUE, NULL, 202),

-- 高齢者向け特別教育
('elderly_driver', '高齢運転者教育', 'Elderly Driver Training',
 '65歳以上のドライバー向けの教育', TRUE, 12, 203);

-- Comment
COMMENT ON TABLE training_type_master IS '研修種別マスタ - 貨物自動車運送事業法施行規則第10条に基づく12項目を含む';
