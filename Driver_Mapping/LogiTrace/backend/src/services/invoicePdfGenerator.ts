/**
 * Invoice PDF Generator Service - 請求書PDF生成
 * インボイス制度（適格請求書）対応
 */

import PDFDocument from 'pdfkit';
import fs from 'fs';
import path from 'path';
import { pool } from '../index';

interface InvoiceData {
    id: number;
    invoiceNumber: string;
    invoiceDate: string;
    dueDate: string;
    billingPeriodStart?: string;
    billingPeriodEnd?: string;
    isQualifiedInvoice: boolean;
    registrationNumber?: string;
    subtotal: number;
    taxRate: number;
    taxAmount: number;
    totalAmount: number;
    notes?: string;
    // 発行元
    companyName: string;
    companyAddress: string;
    companyPhone?: string;
    companyRegistrationNumber?: string;
    // 請求先
    shipperName: string;
    shipperAddress?: string;
    shipperContact?: string;
    // 明細
    items: InvoiceItem[];
}

interface InvoiceItem {
    itemType: string;
    description: string;
    quantity: number;
    unit: string;
    unitPrice: number;
    amount: number;
    taxRate: number;
    taxAmount: number;
    workDate?: string;
    routeInfo?: string;
}

// 日本語フォントパス（システムに依存）
const FONT_PATH = process.env.JAPANESE_FONT_PATH || '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc';
const FONT_BOLD_PATH = process.env.JAPANESE_FONT_BOLD_PATH || '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc';

/**
 * 請求書データを取得
 */
async function getInvoiceData(invoiceId: number): Promise<InvoiceData | null> {
    // 請求書情報
    const invoiceResult = await pool.query(`
        SELECT
            i.*,
            s.name AS shipper_name,
            s.address AS shipper_address,
            s.contact_person AS shipper_contact,
            c.name AS company_name,
            c.address AS company_address,
            c.phone AS company_phone
        FROM invoices i
        LEFT JOIN shippers s ON i.shipper_id = s.id
        LEFT JOIN companies c ON i.company_id = c.id
        WHERE i.id = $1
    `, [invoiceId]);

    if (invoiceResult.rows.length === 0) return null;

    const invoice = invoiceResult.rows[0];

    // 明細取得
    const itemsResult = await pool.query(`
        SELECT * FROM invoice_items
        WHERE invoice_id = $1
        ORDER BY sort_order, id
    `, [invoiceId]);

    return {
        id: invoice.id,
        invoiceNumber: invoice.invoice_number,
        invoiceDate: invoice.invoice_date,
        dueDate: invoice.due_date,
        billingPeriodStart: invoice.billing_period_start,
        billingPeriodEnd: invoice.billing_period_end,
        isQualifiedInvoice: invoice.is_qualified_invoice,
        registrationNumber: invoice.registration_number,
        subtotal: parseFloat(invoice.subtotal),
        taxRate: parseFloat(invoice.tax_rate),
        taxAmount: parseFloat(invoice.tax_amount),
        totalAmount: parseFloat(invoice.total_amount),
        notes: invoice.notes,
        companyName: invoice.company_name,
        companyAddress: invoice.company_address,
        companyPhone: invoice.company_phone,
        companyRegistrationNumber: invoice.registration_number,
        shipperName: invoice.shipper_name,
        shipperAddress: invoice.shipper_address,
        shipperContact: invoice.shipper_contact,
        items: itemsResult.rows.map(item => ({
            itemType: item.item_type,
            description: item.description,
            quantity: parseFloat(item.quantity),
            unit: item.unit,
            unitPrice: parseFloat(item.unit_price),
            amount: parseFloat(item.amount),
            taxRate: parseFloat(item.tax_rate),
            taxAmount: parseFloat(item.tax_amount),
            workDate: item.work_date,
            routeInfo: item.route_info
        }))
    };
}

/**
 * 金額フォーマット
 */
function formatCurrency(amount: number): string {
    return '¥' + amount.toLocaleString('ja-JP');
}

/**
 * 日付フォーマット
 */
function formatDate(dateStr: string): string {
    const date = new Date(dateStr);
    return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
}

/**
 * 請求書PDFを生成
 */
export async function generateInvoicePdf(invoiceId: number): Promise<string> {
    const data = await getInvoiceData(invoiceId);
    if (!data) {
        throw new Error('請求書が見つかりません');
    }

    // 出力パス
    const uploadsDir = path.join(__dirname, '../../uploads/invoices');
    if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const fileName = `invoice_${data.invoiceNumber.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`;
    const filePath = path.join(uploadsDir, fileName);

    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({
                size: 'A4',
                margin: 50,
                info: {
                    Title: `請求書 ${data.invoiceNumber}`,
                    Author: data.companyName,
                    Subject: `${data.shipperName} 様宛 請求書`
                }
            });

            const stream = fs.createWriteStream(filePath);
            doc.pipe(stream);

            // フォント登録（日本語対応）
            // 注: 実際のデプロイ環境では適切なフォントパスを設定
            try {
                doc.registerFont('Japanese', FONT_PATH);
                doc.registerFont('JapaneseBold', FONT_BOLD_PATH);
                doc.font('Japanese');
            } catch {
                // フォントがない場合はデフォルトを使用
                console.warn('Japanese font not found, using default font');
            }

            const pageWidth = doc.page.width - 100;
            let y = 50;

            // ===== ヘッダー =====
            // タイトル
            doc.fontSize(24).text('請求書', 50, y, { align: 'center' });
            y += 40;

            // 適格請求書表示
            if (data.isQualifiedInvoice) {
                doc.fontSize(10).text('（適格請求書）', 50, y, { align: 'center' });
                y += 20;
            }

            // 請求書番号・日付（右側）
            doc.fontSize(10);
            const rightX = 400;
            doc.text(`請求書番号: ${data.invoiceNumber}`, rightX, y);
            y += 15;
            doc.text(`発行日: ${formatDate(data.invoiceDate)}`, rightX, y);
            y += 15;
            doc.text(`お支払期限: ${formatDate(data.dueDate)}`, rightX, y);
            y += 30;

            // 請求先（左側）
            doc.fontSize(14).text(`${data.shipperName} 御中`, 50, y - 45);
            if (data.shipperAddress) {
                doc.fontSize(10).text(data.shipperAddress, 50, y - 30);
            }

            // 区切り線
            doc.moveTo(50, y).lineTo(pageWidth + 50, y).stroke();
            y += 20;

            // ===== 請求金額 =====
            doc.fontSize(12).text('ご請求金額', 50, y);
            y += 5;
            doc.fontSize(24).text(formatCurrency(data.totalAmount), 50, y);
            doc.fontSize(12).text('（税込）', 200, y + 10);
            y += 40;

            // 期間
            if (data.billingPeriodStart && data.billingPeriodEnd) {
                doc.fontSize(10).text(
                    `対象期間: ${formatDate(data.billingPeriodStart)} ～ ${formatDate(data.billingPeriodEnd)}`,
                    50, y
                );
                y += 20;
            }

            // 区切り線
            doc.moveTo(50, y).lineTo(pageWidth + 50, y).stroke();
            y += 10;

            // ===== 明細テーブル =====
            const tableTop = y;
            const colWidths = [200, 60, 40, 80, 80];
            const colX = [50, 250, 310, 350, 430];

            // ヘッダー行
            doc.fontSize(9).fillColor('#666666');
            doc.rect(50, y, pageWidth, 20).fill('#f5f5f5');
            doc.fillColor('#333333');
            y += 5;
            doc.text('摘要', colX[0] + 5, y);
            doc.text('数量', colX[1] + 5, y);
            doc.text('単位', colX[2] + 5, y);
            doc.text('単価', colX[3] + 5, y, { align: 'right', width: colWidths[3] - 10 });
            doc.text('金額', colX[4] + 5, y, { align: 'right', width: colWidths[4] - 10 });
            y += 20;

            // 明細行
            doc.fontSize(9).fillColor('#333333');
            for (const item of data.items) {
                // ページ送り確認
                if (y > 700) {
                    doc.addPage();
                    y = 50;
                }

                // 背景色（交互）
                const rowIndex = data.items.indexOf(item);
                if (rowIndex % 2 === 1) {
                    doc.rect(50, y - 3, pageWidth, 18).fill('#fafafa');
                    doc.fillColor('#333333');
                }

                // 摘要（2行対応）
                let description = item.description;
                if (item.workDate) {
                    description = `[${item.workDate}] ${description}`;
                }
                if (item.routeInfo) {
                    description += `\n${item.routeInfo}`;
                }

                doc.text(description, colX[0] + 5, y, { width: colWidths[0] - 10 });
                doc.text(item.quantity.toString(), colX[1] + 5, y);
                doc.text(item.unit, colX[2] + 5, y);
                doc.text(formatCurrency(item.unitPrice), colX[3] + 5, y, { align: 'right', width: colWidths[3] - 10 });
                doc.text(formatCurrency(item.amount), colX[4] + 5, y, { align: 'right', width: colWidths[4] - 10 });

                y += description.includes('\n') ? 28 : 18;
            }

            y += 10;

            // 区切り線
            doc.moveTo(50, y).lineTo(pageWidth + 50, y).stroke();
            y += 15;

            // ===== 合計 =====
            const summaryX = 350;
            doc.fontSize(10);

            // 小計
            doc.text('小計', summaryX, y);
            doc.text(formatCurrency(data.subtotal), summaryX + 80, y, { align: 'right', width: 80 });
            y += 18;

            // 消費税
            doc.text(`消費税（${data.taxRate}%）`, summaryX, y);
            doc.text(formatCurrency(data.taxAmount), summaryX + 80, y, { align: 'right', width: 80 });
            y += 18;

            // 合計
            doc.rect(summaryX - 5, y - 3, 170, 25).fill('#1a237e');
            doc.fillColor('#ffffff').fontSize(12);
            doc.text('合計', summaryX, y + 2);
            doc.text(formatCurrency(data.totalAmount), summaryX + 80, y + 2, { align: 'right', width: 80 });
            doc.fillColor('#333333');
            y += 40;

            // ===== 発行元情報 =====
            y = 680; // 固定位置

            doc.fontSize(10);
            doc.text(data.companyName, 350, y);
            y += 15;
            if (data.companyAddress) {
                doc.fontSize(9).text(data.companyAddress, 350, y);
                y += 12;
            }
            if (data.companyPhone) {
                doc.text(`TEL: ${data.companyPhone}`, 350, y);
                y += 12;
            }

            // 登録番号（インボイス制度）
            if (data.isQualifiedInvoice && data.companyRegistrationNumber) {
                doc.fontSize(9).text(`登録番号: ${data.companyRegistrationNumber}`, 350, y);
            }

            // 備考
            if (data.notes) {
                doc.fontSize(8).text('備考:', 50, 720);
                doc.text(data.notes, 50, 732, { width: 250 });
            }

            // フッター
            doc.fontSize(8).fillColor('#999999');
            doc.text(
                'この請求書は電子的に作成されており、署名は不要です。',
                50, 780, { align: 'center', width: pageWidth }
            );

            doc.end();

            stream.on('finish', async () => {
                // DBにPDF URLを保存
                const pdfUrl = `/uploads/invoices/${fileName}`;
                await pool.query(`
                    UPDATE invoices SET
                        pdf_url = $1,
                        pdf_generated_at = NOW(),
                        updated_at = NOW()
                    WHERE id = $2
                `, [pdfUrl, invoiceId]);

                resolve(pdfUrl);
            });

            stream.on('error', reject);
        } catch (error) {
            reject(error);
        }
    });
}

/**
 * 下払通知書PDFを生成
 */
export async function generateSubcontractPaymentPdf(paymentId: number): Promise<string> {
    // 下払通知書情報取得
    const result = await pool.query(`
        SELECT sp.*, c.name AS company_name, c.address AS company_address
        FROM subcontract_payments sp
        LEFT JOIN companies c ON sp.company_id = c.id
        WHERE sp.id = $1
    `, [paymentId]);

    if (result.rows.length === 0) {
        throw new Error('下払通知書が見つかりません');
    }

    const payment = result.rows[0];

    // 明細取得
    const itemsResult = await pool.query(`
        SELECT * FROM subcontract_payment_items
        WHERE subcontract_payment_id = $1
        ORDER BY sort_order, id
    `, [paymentId]);

    // 出力パス
    const uploadsDir = path.join(__dirname, '../../uploads/subcontract_payments');
    if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
    }

    const fileName = `subcontract_${payment.payment_number.replace(/[^a-zA-Z0-9]/g, '_')}.pdf`;
    const filePath = path.join(uploadsDir, fileName);

    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({
                size: 'A4',
                margin: 50
            });

            const stream = fs.createWriteStream(filePath);
            doc.pipe(stream);

            // フォント登録
            try {
                doc.registerFont('Japanese', FONT_PATH);
                doc.font('Japanese');
            } catch {
                console.warn('Japanese font not found');
            }

            let y = 50;

            // タイトル
            doc.fontSize(24).text('下払通知書', 50, y, { align: 'center' });
            y += 50;

            // 通知書番号・日付
            doc.fontSize(10);
            doc.text(`通知書番号: ${payment.payment_number}`, 400, y - 30);
            doc.text(`発行日: ${formatDate(payment.payment_date)}`, 400, y - 15);

            // 支払先
            doc.fontSize(14).text(`${payment.subcontractor_name} 御中`, 50, y);
            y += 20;
            if (payment.subcontractor_address) {
                doc.fontSize(10).text(payment.subcontractor_address, 50, y);
                y += 15;
            }

            y += 20;

            // 支払金額
            doc.fontSize(12).text('お支払金額', 50, y);
            y += 5;
            doc.fontSize(24).text(formatCurrency(parseFloat(payment.total_amount)), 50, y);
            doc.fontSize(12).text('（税込）', 200, y + 10);
            y += 50;

            // 明細（簡略版）
            doc.fontSize(10);
            doc.text('【明細】', 50, y);
            y += 15;

            for (const item of itemsResult.rows) {
                doc.text(`・${item.description}: ${formatCurrency(parseFloat(item.amount))}`, 60, y);
                y += 15;
            }

            y += 20;

            // 合計
            doc.text(`小計: ${formatCurrency(parseFloat(payment.subtotal))}`, 300, y);
            y += 15;
            doc.text(`消費税: ${formatCurrency(parseFloat(payment.tax_amount))}`, 300, y);
            y += 15;
            doc.text(`合計: ${formatCurrency(parseFloat(payment.total_amount))}`, 300, y);

            // 発行元
            y = 680;
            doc.text(payment.company_name, 350, y);
            if (payment.company_address) {
                doc.text(payment.company_address, 350, y + 15);
            }

            doc.end();

            stream.on('finish', async () => {
                const pdfUrl = `/uploads/subcontract_payments/${fileName}`;
                await pool.query(`
                    UPDATE subcontract_payments SET pdf_url = $1 WHERE id = $2
                `, [pdfUrl, paymentId]);
                resolve(pdfUrl);
            });

            stream.on('error', reject);
        } catch (error) {
            reject(error);
        }
    });
}
