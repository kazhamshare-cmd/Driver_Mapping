import { Link } from 'react-router-dom';
import { Box, Button, Card, CardContent, Container, Grid, Typography, Chip, Avatar, Stack } from '@mui/material';
import CheckCircleOutline from '@mui/icons-material/CheckCircleOutline';
import HighlightOff from '@mui/icons-material/HighlightOff';
import {
    LocalShipping,
    DirectionsCar,
    DirectionsBus,
    Speed,
    Description,
    FactCheck,
    Badge,
    LocalHospital,
    School,
    Psychology,
    PictureAsPdf,
    Security,
    CloudSync,
    PhoneAndroid,
    TrendingUp,
    AccessTime,
    AttachMoney,
    ArrowForward,
    PlayArrow,
} from '@mui/icons-material';

export default function Home() {
    return (
        <>
            {/* Hero Section - モダンなグラデーション背景 */}
            <Box sx={{
                pt: { xs: 8, md: 12 },
                pb: { xs: 10, md: 24 }, // Extended bottom padding for the floating mockups
                background: 'radial-gradient(circle at 80% 20%, #1565c0 0%, #0d47a1 50%, #002171 100%)',
                position: 'relative',
                overflow: 'hidden',
            }}>
                {/* Background decorations */}
                <Box sx={{
                    position: 'absolute',
                    top: -200,
                    right: -200,
                    width: 600,
                    height: 600,
                    borderRadius: '50%',
                    background: 'radial-gradient(circle, rgba(255,255,255,0.05) 0%, transparent 70%)',
                    zIndex: 0
                }} />

                <Container maxWidth="lg" sx={{ position: 'relative', zIndex: 1 }}>
                    <Grid container spacing={8} alignItems="center">
                        <Grid size={{ xs: 12, md: 6 }}>
                            <Stack direction="row" spacing={1} sx={{ mb: 3 }}>
                                <Chip
                                    label="DX推進をサポート"
                                    size="small"
                                    sx={{ bgcolor: 'rgba(255,255,255,0.1)', color: '#81d4fa', border: '1px solid rgba(129, 212, 250, 0.3)' }}
                                />
                            </Stack>
                            <Typography variant="h2" component="h1" fontWeight="800" sx={{ mb: 3, color: 'white', lineHeight: 1.1, letterSpacing: -1 }}>
                                運送業務を、<br />
                                <span style={{ color: '#4fc3f7', display: 'inline-block', transform: 'scale(1.02)', transformOrigin: 'left bottom' }}>もっとスマートに。</span>
                            </Typography>
                            <Typography variant="h6" sx={{ mb: 4, color: 'rgba(255,255,255,0.8)', lineHeight: 1.8, maxWidth: 500 }}>
                                リアルタイムな動態管理から、複雑な帳票作成まで。<br />
                                LogiTraceは、運送会社の業務を一元管理する<br />
                                次世代のクラウドプラットフォームです。
                            </Typography>
                            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                                <Button
                                    component={Link}
                                    to="/register"
                                    variant="contained"
                                    size="large"
                                    startIcon={<PlayArrow />}
                                    sx={{
                                        bgcolor: '#29b6f6',
                                        color: '#01579b',
                                        fontWeight: 'bold',
                                        px: 4,
                                        py: 1.5,
                                        fontSize: '1.1rem',
                                        boxShadow: '0 8px 16px rgba(41, 182, 246, 0.3)',
                                        '&:hover': { bgcolor: '#4fc3f7' }
                                    }}
                                >
                                    無料で始める
                                </Button>
                                <Button
                                    component={Link}
                                    to="/login"
                                    variant="outlined"
                                    size="large"
                                    sx={{
                                        borderColor: 'rgba(255,255,255,0.3)',
                                        color: 'white',
                                        px: 4,
                                        '&:hover': { borderColor: 'white', bgcolor: 'rgba(255,255,255,0.05)' }
                                    }}
                                >
                                    ログイン
                                </Button>
                            </Stack>
                        </Grid>

                        {/* Right Side: CSS Browser Mockup */}
                        <Grid size={{ xs: 12, md: 6 }} sx={{ position: 'relative' }}>
                            {/* Browser Window Frame */}
                            <Box sx={{
                                bgcolor: '#fff',
                                borderRadius: 2,
                                boxShadow: '0 20px 60px rgba(0,0,0,0.4)',
                                overflow: 'hidden',
                                transform: 'perspective(1000px) rotateY(-5deg) rotateX(2deg)',
                                transition: 'transform 0.3s',
                                '&:hover': { transform: 'perspective(1000px) rotateY(-2deg) rotateX(1deg) translateY(-10px)' }
                            }}>
                                {/* Browser Header */}
                                <Box sx={{ bgcolor: '#f5f5f5', px: 2, py: 1.5, borderBottom: '1px solid #e0e0e0', display: 'flex', gap: 1 }}>
                                    <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: '#ff5f56' }} />
                                    <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: '#ffbd2e' }} />
                                    <Box sx={{ width: 10, height: 10, borderRadius: '50%', bgcolor: '#27c93f' }} />
                                </Box>

                                {/* App Mockup Content */}
                                <Box sx={{ height: 350, bgcolor: '#f8fbff', p: 2, display: 'flex', gap: 2 }}>
                                    {/* Sidebar Mockup */}
                                    <Box sx={{ width: 60, bgcolor: '#1a237e', borderRadius: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, py: 2 }}>
                                        <Box sx={{ width: 32, height: 32, bgcolor: 'rgba(255,255,255,0.2)', borderRadius: 1 }} />
                                        <Box sx={{ width: 24, height: 4, bgcolor: 'rgba(255,255,255,0.1)', borderRadius: 1, mt: 2 }} />
                                        <Box sx={{ width: 24, height: 4, bgcolor: 'rgba(255,255,255,0.1)', borderRadius: 1 }} />
                                        <Box sx={{ width: 24, height: 4, bgcolor: 'rgba(255,255,255,0.1)', borderRadius: 1 }} />
                                    </Box>

                                    {/* Main Content Mockup */}
                                    <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
                                        {/* Header Mockup */}
                                        <Box sx={{ height: 40, bgcolor: 'white', borderRadius: 1, boxShadow: '0 2px 4px rgba(0,0,0,0.02)', display: 'flex', alignItems: 'center', px: 2 }}>
                                            <Box sx={{ width: 100, height: 8, bgcolor: '#e0e0e0', borderRadius: 4 }} />
                                        </Box>

                                        {/* Dashboard Widgets Mockup */}
                                        <Box sx={{ display: 'flex', gap: 2 }}>
                                            <Box sx={{ flex: 1, height: 80, bgcolor: 'white', borderRadius: 2, p: 1.5, boxShadow: '0 2px 8px rgba(0,0,0,0.03)' }}>
                                                <Box sx={{ width: 24, height: 24, bgcolor: '#e3f2fd', borderRadius: 1, mb: 1 }} />
                                                <Box sx={{ width: '40%', height: 6, bgcolor: '#e0e0e0', borderRadius: 4 }} />
                                            </Box>
                                            <Box sx={{ flex: 1, height: 80, bgcolor: 'white', borderRadius: 2, p: 1.5, boxShadow: '0 2px 8px rgba(0,0,0,0.03)' }}>
                                                <Box sx={{ width: 24, height: 24, bgcolor: '#e8f5e9', borderRadius: 1, mb: 1 }} />
                                                <Box sx={{ width: '40%', height: 6, bgcolor: '#e0e0e0', borderRadius: 4 }} />
                                            </Box>
                                            <Box sx={{ flex: 1, height: 80, bgcolor: 'white', borderRadius: 2, p: 1.5, boxShadow: '0 2px 8px rgba(0,0,0,0.03)' }}>
                                                <Box sx={{ width: 24, height: 24, bgcolor: '#fff3e0', borderRadius: 1, mb: 1 }} />
                                                <Box sx={{ width: '40%', height: 6, bgcolor: '#e0e0e0', borderRadius: 4 }} />
                                            </Box>
                                        </Box>

                                        {/* Map/Chart Area Mockup */}
                                        <Box sx={{ flex: 1, bgcolor: 'white', borderRadius: 2, p: 2, boxShadow: '0 2px 8px rgba(0,0,0,0.03)', position: 'relative', overflow: 'hidden' }}>
                                            {/* Fake Map Elements */}
                                            <Box sx={{ position: 'absolute', top: '50%', left: '30%', width: 8, height: 8, bgcolor: '#2196f3', borderRadius: '50%', boxShadow: '0 0 0 4px rgba(33, 150, 243, 0.2)' }} />
                                            <Box sx={{ position: 'absolute', top: '30%', left: '60%', width: 8, height: 8, bgcolor: '#4caf50', borderRadius: '50%', boxShadow: '0 0 0 4px rgba(76, 175, 80, 0.2)' }} />
                                            <Box sx={{ position: 'absolute', top: 0, left: 0, width: '100%', height: '100%', background: 'radial-gradient(circle at 50% 50%, #f5f5f5 1px, transparent 1px)', backgroundSize: '20px 20px', opacity: 0.5 }} />
                                        </Box>
                                    </Box>
                                </Box>
                            </Box>

                            {/* Floating Elements */}
                            <Box sx={{
                                position: 'absolute',
                                bottom: -40,
                                left: -40,
                                bgcolor: 'rgba(255,255,255,0.95)',
                                backdropFilter: 'blur(10px)',
                                borderRadius: 3,
                                p: 2,
                                boxShadow: '0 10px 30px rgba(0,0,0,0.2)',
                                display: 'flex',
                                alignItems: 'center',
                                gap: 2,
                                zIndex: 10
                            }}>
                                <CheckCircleOutline color="success" sx={{ fontSize: 32 }} />
                                <Box>
                                    <Typography variant="subtitle2" fontWeight="bold">監査対応完了</Typography>
                                    <Typography variant="caption" color="text.secondary">2024年10月度</Typography>
                                </Box>
                            </Box>
                        </Grid>
                    </Grid>
                </Container>
            </Box>

            {/* 対応業種セクション */}
            <Box sx={{ py: 6, bgcolor: 'white', borderBottom: '1px solid #eee' }}>
                <Container maxWidth="lg">
                    <Grid container spacing={4} alignItems="center" justifyContent="center">
                        <Grid size={{ xs: 12, md: 3 }}>
                            <Typography variant="body1" color="text.secondary" fontWeight="bold">
                                対応業種
                            </Typography>
                        </Grid>
                        <Grid size={{ xs: 4, md: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <LocalShipping sx={{ fontSize: 40, color: '#1976d2' }} />
                                <Box>
                                    <Typography fontWeight="bold">トラック運送</Typography>
                                    <Typography variant="caption" color="text.secondary">一般貨物・特積み</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 4, md: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <DirectionsCar sx={{ fontSize: 40, color: '#388e3c' }} />
                                <Box>
                                    <Typography fontWeight="bold">タクシー</Typography>
                                    <Typography variant="caption" color="text.secondary">法人・個人</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 4, md: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <DirectionsBus sx={{ fontSize: 40, color: '#f57c00' }} />
                                <Box>
                                    <Typography fontWeight="bold">バス</Typography>
                                    <Typography variant="caption" color="text.secondary">貸切・路線</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                    </Grid>
                </Container>
            </Box>

            {/* 導入ステップセクション */}
            <Box sx={{ py: 10, bgcolor: '#f8f9fa' }}>
                <Container maxWidth="lg">
                    <Box sx={{ textAlign: 'center', mb: 8 }}>
                        <Chip label="SIMPLE STEPS" color="primary" size="small" sx={{ mb: 2 }} />
                        <Typography variant="h3" fontWeight="bold" sx={{ mb: 2 }}>
                            かんたん3ステップで導入
                        </Typography>
                        <Typography variant="h6" color="text.secondary">
                            専門知識不要。最短30分で運用開始できます
                        </Typography>
                    </Box>

                    <Grid container spacing={4}>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Card sx={{ height: '100%', borderRadius: 4, boxShadow: '0 4px 20px rgba(0,0,0,0.08)', position: 'relative', overflow: 'visible' }}>
                                <Box sx={{
                                    position: 'absolute',
                                    top: -20,
                                    left: 24,
                                    width: 48,
                                    height: 48,
                                    borderRadius: '50%',
                                    bgcolor: '#1976d2',
                                    color: 'white',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    fontWeight: 'bold',
                                    fontSize: 20,
                                }}>
                                    1
                                </Box>
                                <CardContent sx={{ pt: 5, pb: 4, px: 3 }}>
                                    <Typography variant="h5" fontWeight="bold" sx={{ mb: 2 }}>
                                        アカウント登録
                                    </Typography>
                                    <Typography color="text.secondary" sx={{ mb: 3 }}>
                                        会社情報とドライバー情報を入力。
                                        CSVで一括インポートも可能です。
                                    </Typography>
                                    <Stack direction="row" spacing={1}>
                                        <Chip label="メール認証" size="small" variant="outlined" />
                                        <Chip label="CSV対応" size="small" variant="outlined" />
                                    </Stack>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Card sx={{ height: '100%', borderRadius: 4, boxShadow: '0 4px 20px rgba(0,0,0,0.08)', position: 'relative', overflow: 'visible' }}>
                                <Box sx={{
                                    position: 'absolute',
                                    top: -20,
                                    left: 24,
                                    width: 48,
                                    height: 48,
                                    borderRadius: '50%',
                                    bgcolor: '#388e3c',
                                    color: 'white',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    fontWeight: 'bold',
                                    fontSize: 20,
                                }}>
                                    2
                                </Box>
                                <CardContent sx={{ pt: 5, pb: 4, px: 3 }}>
                                    <Typography variant="h5" fontWeight="bold" sx={{ mb: 2 }}>
                                        車両・ドライバー設定
                                    </Typography>
                                    <Typography color="text.secondary" sx={{ mb: 3 }}>
                                        運転者台帳・車両情報を登録。
                                        免許・健診の期限も自動管理されます。
                                    </Typography>
                                    <Stack direction="row" spacing={1}>
                                        <Chip label="期限アラート" size="small" variant="outlined" />
                                        <Chip label="自動通知" size="small" variant="outlined" />
                                    </Stack>
                                </CardContent>
                            </Card>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Card sx={{ height: '100%', borderRadius: 4, boxShadow: '0 4px 20px rgba(0,0,0,0.08)', position: 'relative', overflow: 'visible' }}>
                                <Box sx={{
                                    position: 'absolute',
                                    top: -20,
                                    left: 24,
                                    width: 48,
                                    height: 48,
                                    borderRadius: '50%',
                                    bgcolor: '#f57c00',
                                    color: 'white',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    fontWeight: 'bold',
                                    fontSize: 20,
                                }}>
                                    3
                                </Box>
                                <CardContent sx={{ pt: 5, pb: 4, px: 3 }}>
                                    <Typography variant="h5" fontWeight="bold" sx={{ mb: 2 }}>
                                        運用開始
                                    </Typography>
                                    <Typography color="text.secondary" sx={{ mb: 3 }}>
                                        点呼・点検をスマホで記録。
                                        日報はGPSと連動で自動作成。
                                    </Typography>
                                    <Stack direction="row" spacing={1}>
                                        <Chip label="スマホ対応" size="small" variant="outlined" />
                                        <Chip label="GPS連動" size="small" variant="outlined" />
                                    </Stack>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>
                </Container>
            </Box>

            {/* 機能一覧セクション */}
            <Box sx={{ py: 10, bgcolor: 'white' }}>
                <Container maxWidth="lg">
                    <Box sx={{ textAlign: 'center', mb: 8 }}>
                        <Chip label="FEATURES" color="primary" size="small" sx={{ mb: 2 }} />
                        <Typography variant="h3" fontWeight="bold" sx={{ mb: 2 }}>
                            法定帳票をオールインワンで管理
                        </Typography>
                        <Typography variant="h6" color="text.secondary">
                            運送業法が求めるすべての記録を、このシステム1つで完結
                        </Typography>
                    </Box>

                    <Grid container spacing={3}>
                        <FeatureCard
                            icon={<FactCheck sx={{ fontSize: 48, color: '#1976d2' }} />}
                            title="点呼記録簿"
                            description="乗務前・乗務後点呼をデジタル化。アルコールチェック結果も記録。"
                            tags={['IT点呼対応', '自動保存']}
                        />
                        <FeatureCard
                            icon={<Speed sx={{ fontSize: 48, color: '#388e3c' }} />}
                            title="日常点検記録"
                            description="車両の日常点検をチェックリスト形式で。不良箇所は即通知。"
                            tags={['写真添付', '不良アラート']}
                        />
                        <FeatureCard
                            icon={<Description sx={{ fontSize: 48, color: '#f57c00' }} />}
                            title="運転日報"
                            description="GPSと連動して走行記録を自動作成。手書き不要で正確。"
                            tags={['GPS連動', '自動作成']}
                        />
                        <FeatureCard
                            icon={<Badge sx={{ fontSize: 48, color: '#7b1fa2' }} />}
                            title="運転者台帳"
                            description="法定様式に準拠した運転者台帳。免許期限を自動アラート。"
                            tags={['法定様式', '期限管理']}
                        />
                        <FeatureCard
                            icon={<LocalHospital sx={{ fontSize: 48, color: '#d32f2f' }} />}
                            title="健康診断管理"
                            description="定期健診・特殊健診の受診履歴と次回予定を一元管理。"
                            tags={['受診履歴', '次回通知']}
                        />
                        <FeatureCard
                            icon={<Psychology sx={{ fontSize: 48, color: '#0288d1' }} />}
                            title="適性診断管理"
                            description="初任・適齢・特定診断の記録管理。65歳以上は自動で適齢判定。"
                            tags={['自動判定', '記録保存']}
                        />
                        <FeatureCard
                            icon={<School sx={{ fontSize: 48, color: '#689f38' }} />}
                            title="教育研修記録"
                            description="安全運転教育の実施記録。12項目の指導もチェック管理。"
                            tags={['12項目対応', '履歴管理']}
                        />
                        <FeatureCard
                            icon={<PictureAsPdf sx={{ fontSize: 48, color: '#c62828' }} />}
                            title="監査用PDF出力"
                            description="すべての帳票をPDFで出力。監査時もワンクリックで対応。"
                            tags={['一括出力', '監査対応']}
                        />
                    </Grid>
                </Container>
            </Box>

            {/* 効果・メリットセクション */}
            <Box sx={{ py: 10, bgcolor: '#1a237e', color: 'white' }}>
                <Container maxWidth="lg">
                    <Box sx={{ textAlign: 'center', mb: 8 }}>
                        <Chip label="BENEFITS" size="small" sx={{ mb: 2, bgcolor: 'rgba(255,255,255,0.2)', color: 'white' }} />
                        <Typography variant="h3" fontWeight="bold" sx={{ mb: 2 }}>
                            導入で変わる3つのこと
                        </Typography>
                    </Box>

                    <Grid container spacing={4}>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Box sx={{ textAlign: 'center', p: 4 }}>
                                <Avatar sx={{ width: 80, height: 80, bgcolor: '#4fc3f7', mx: 'auto', mb: 3 }}>
                                    <AccessTime sx={{ fontSize: 40 }} />
                                </Avatar>
                                <Typography variant="h4" fontWeight="bold" sx={{ mb: 1 }}>
                                    時間削減
                                </Typography>
                                <Typography variant="h2" fontWeight="bold" sx={{ color: '#4fc3f7', mb: 2 }}>
                                    -80%
                                </Typography>
                                <Typography sx={{ color: 'rgba(255,255,255,0.8)' }}>
                                    手書き日報・転記作業が不要に。<br />
                                    管理者の事務作業を大幅削減。
                                </Typography>
                            </Box>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Box sx={{ textAlign: 'center', p: 4 }}>
                                <Avatar sx={{ width: 80, height: 80, bgcolor: '#4fc3f7', mx: 'auto', mb: 3 }}>
                                    <AttachMoney sx={{ fontSize: 40 }} />
                                </Avatar>
                                <Typography variant="h4" fontWeight="bold" sx={{ mb: 1 }}>
                                    コスト削減
                                </Typography>
                                <Typography variant="h2" fontWeight="bold" sx={{ color: '#4fc3f7', mb: 2 }}>
                                    -50%
                                </Typography>
                                <Typography sx={{ color: 'rgba(255,255,255,0.8)' }}>
                                    紙・印刷費ゼロ、人件費も削減。<br />
                                    月額費用で導入も低リスク。
                                </Typography>
                            </Box>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Box sx={{ textAlign: 'center', p: 4 }}>
                                <Avatar sx={{ width: 80, height: 80, bgcolor: '#4fc3f7', mx: 'auto', mb: 3 }}>
                                    <Security sx={{ fontSize: 40 }} />
                                </Avatar>
                                <Typography variant="h4" fontWeight="bold" sx={{ mb: 1 }}>
                                    監査対応
                                </Typography>
                                <Typography variant="h2" fontWeight="bold" sx={{ color: '#4fc3f7', mb: 2 }}>
                                    100%
                                </Typography>
                                <Typography sx={{ color: 'rgba(255,255,255,0.8)' }}>
                                    法定様式に完全準拠。<br />
                                    監査時も慌てず書類を提出。
                                </Typography>
                            </Box>
                        </Grid>
                    </Grid>
                </Container>
            </Box>

            {/* 技術的特長 */}
            <Box sx={{ py: 8, bgcolor: 'white' }}>
                <Container maxWidth="lg">
                    <Grid container spacing={4} alignItems="center">
                        <Grid size={{ xs: 6, sm: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <CloudSync color="primary" sx={{ fontSize: 32 }} />
                                <Box>
                                    <Typography fontWeight="bold">クラウド対応</Typography>
                                    <Typography variant="caption" color="text.secondary">どこからでもアクセス</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <PhoneAndroid color="success" sx={{ fontSize: 32 }} />
                                <Box>
                                    <Typography fontWeight="bold">スマホ対応</Typography>
                                    <Typography variant="caption" color="text.secondary">現場で記録可能</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <Security color="error" sx={{ fontSize: 32 }} />
                                <Box>
                                    <Typography fontWeight="bold">SSL暗号化</Typography>
                                    <Typography variant="caption" color="text.secondary">安全な通信</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 6, sm: 3 }}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="center">
                                <TrendingUp color="warning" sx={{ fontSize: 32 }} />
                                <Box>
                                    <Typography fontWeight="bold">自動バックアップ</Typography>
                                    <Typography variant="caption" color="text.secondary">データ紛失防止</Typography>
                                </Box>
                            </Stack>
                        </Grid>
                    </Grid>
                </Container>
            </Box>

            {/* 料金プランセクション */}
            <Box sx={{ py: 10, backgroundColor: '#f8f9fa' }}>
                <Container maxWidth="lg">
                    <Box sx={{ textAlign: 'center', mb: 8 }}>
                        <Chip label="PRICING" color="primary" size="small" sx={{ mb: 2 }} />
                        <Typography variant="h3" fontWeight="bold" sx={{ mb: 2 }}>
                            シンプルな料金プラン
                        </Typography>
                        <Typography variant="h6" color="text.secondary" sx={{ mb: 2 }}>
                            すべてのプランに14日間の無料トライアル付き
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            クレジットカードを登録して今すぐ開始。14日以内にキャンセルすれば課金されません。
                        </Typography>
                    </Box>

                    {/* 3プラン表示（スモール・スタンダード・プロ） */}
                    <Grid container spacing={3} alignItems="center" justifyContent="center" sx={{ pt: 4 }}>
                        {/* スモールプラン */}
                        <Grid size={{ xs: 12, md: 3.5 }}>
                            <Card sx={{
                                border: '1px solid #eee',
                                borderRadius: 4,
                                p: 2,
                                height: '100%',
                                boxShadow: '0 4px 12px rgba(0,0,0,0.05)',
                            }}>
                                <CardContent>
                                    <Typography variant="h6" fontWeight="bold" sx={{ mb: 1 }}>スモールプラン</Typography>
                                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>小規模事業者向け</Typography>
                                    <Box sx={{ mb: 2 }}>
                                        <Typography variant="h4" component="span" fontWeight="bold">¥1,980</Typography>
                                        <Typography component="span" color="text.secondary">/月</Typography>
                                    </Box>
                                    <Typography variant="body2" sx={{ mb: 2, color: 'text.secondary' }}>1〜3名のドライバー</Typography>
                                    <Box component="ul" sx={{ listStyle: 'none', p: 0, m: 0, mb: 2 }}>
                                        <FeatureItem label="管理者: 1名" />
                                        <FeatureItem label="GPS追跡" />
                                        <FeatureItem label="日報作成" />
                                        <FeatureItem label="PDFエクスポート" />
                                        <FeatureItem label="保存期間: 3ヶ月" />
                                        <FeatureItem label="メールサポート" />
                                    </Box>
                                    <Button component={Link} to="/register?plan=small" variant="outlined" fullWidth>
                                        14日間無料で試す
                                    </Button>
                                </CardContent>
                            </Card>
                        </Grid>

                        {/* スタンダードプラン（中央・強調） */}
                        <Grid size={{ xs: 12, md: 5 }}>
                            <Card sx={{
                                border: '3px solid',
                                borderColor: 'primary.main',
                                borderRadius: 4,
                                p: 3,
                                position: 'relative',
                                boxShadow: '0 12px 40px rgba(25, 118, 210, 0.25)',
                                transform: 'scale(1.05)',
                                zIndex: 1,
                                bgcolor: 'white',
                                overflow: 'visible',
                            }}>
                                <Box sx={{
                                    position: 'absolute',
                                    top: -16,
                                    left: '50%',
                                    transform: 'translateX(-50%)',
                                    backgroundColor: 'primary.main',
                                    color: 'white',
                                    py: 1,
                                    px: 3,
                                    borderRadius: '20px',
                                    fontSize: '14px',
                                    fontWeight: 'bold',
                                    boxShadow: '0 4px 12px rgba(25, 118, 210, 0.4)',
                                }}>
                                    一番人気
                                </Box>
                                <CardContent sx={{ pt: 2 }}>
                                    <Typography variant="h5" fontWeight="bold" sx={{ mb: 1, color: 'primary.main' }}>スタンダードプラン</Typography>
                                    <Typography color="text.secondary" sx={{ mb: 2 }}>中小規模事業者向け</Typography>
                                    <Box sx={{ mb: 2 }}>
                                        <Typography variant="h3" component="span" fontWeight="bold" color="primary">¥4,980</Typography>
                                        <Typography component="span" color="text.secondary">/月</Typography>
                                    </Box>
                                    <Typography variant="body2" sx={{ mb: 3, color: 'text.secondary' }}>4〜10名のドライバー</Typography>
                                    <Box component="ul" sx={{ listStyle: 'none', p: 0, m: 0, mb: 3 }}>
                                        <FeatureItem label="管理者: 無制限" />
                                        <FeatureItem label="GPS追跡" />
                                        <FeatureItem label="日報作成" />
                                        <FeatureItem label="PDFエクスポート" />
                                        <FeatureItem label="月次レポート" />
                                        <FeatureItem label="保存期間: 1年" />
                                        <FeatureItem label="メールサポート" />
                                    </Box>
                                    <Button
                                        component={Link}
                                        to="/register?plan=standard"
                                        variant="contained"
                                        fullWidth
                                        size="large"
                                        endIcon={<ArrowForward />}
                                        sx={{ py: 1.5 }}
                                    >
                                        14日間無料で試す
                                    </Button>
                                </CardContent>
                            </Card>
                        </Grid>

                        {/* プロプラン */}
                        <Grid size={{ xs: 12, md: 3.5 }}>
                            <Card sx={{
                                border: '1px solid #eee',
                                borderRadius: 4,
                                p: 2,
                                height: '100%',
                                boxShadow: '0 4px 12px rgba(0,0,0,0.05)',
                            }}>
                                <CardContent>
                                    <Typography variant="h6" fontWeight="bold" sx={{ mb: 1 }}>プロプラン</Typography>
                                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>大規模事業者向け</Typography>
                                    <Box sx={{ mb: 2 }}>
                                        <Typography variant="h4" component="span" fontWeight="bold">¥9,980</Typography>
                                        <Typography component="span" color="text.secondary">/月</Typography>
                                    </Box>
                                    <Typography variant="body2" sx={{ mb: 2, color: 'text.secondary' }}>11〜30名のドライバー</Typography>
                                    <Box component="ul" sx={{ listStyle: 'none', p: 0, m: 0, mb: 2 }}>
                                        <FeatureItem label="管理者: 無制限" />
                                        <FeatureItem label="すべての基本機能" />
                                        <FeatureItem label="年次レポート" />
                                        <FeatureItem label="保存期間: 無制限" />
                                        <FeatureItem label="REST API連携" />
                                        <FeatureItem label="電話サポート" />
                                    </Box>
                                    <Button component={Link} to="/register?plan=pro" variant="outlined" fullWidth>
                                        14日間無料で試す
                                    </Button>
                                </CardContent>
                            </Card>
                        </Grid>
                    </Grid>

                    {/* エンタープライズへの誘導 */}
                    <Box sx={{ textAlign: 'center', mt: 6, p: 4, bgcolor: 'grey.100', borderRadius: 3 }}>
                        <Typography variant="h6" fontWeight="bold" sx={{ mb: 1 }}>
                            31名以上のドライバーをお持ちの企業様
                        </Typography>
                        <Typography color="text.secondary" sx={{ mb: 2 }}>
                            エンタープライズプランでカスタマイズ対応いたします。専任担当者がサポート。
                        </Typography>
                        <Button component={Link} to="/register?plan=enterprise" variant="outlined" color="primary">
                            お問い合わせ
                        </Button>
                    </Box>
                </Container>
            </Box>

            {/* CTA セクション */}
            <Box sx={{ py: 10, bgcolor: '#0d47a1', color: 'white', textAlign: 'center' }}>
                <Container maxWidth="md">
                    <Typography variant="h3" fontWeight="bold" sx={{ mb: 3 }}>
                        まずは14日間、無料でお試しください
                    </Typography>
                    <Typography variant="h6" sx={{ mb: 4, color: 'rgba(255,255,255,0.8)' }}>
                        クレジットカード不要。すべての機能をお試しいただけます。
                    </Typography>
                    <Button
                        component={Link}
                        to="/register"
                        variant="contained"
                        size="large"
                        sx={{
                            bgcolor: 'white',
                            color: '#0d47a1',
                            fontWeight: 'bold',
                            px: 6,
                            py: 2,
                            fontSize: '1.1rem',
                            '&:hover': { bgcolor: '#e3f2fd' }
                        }}
                    >
                        無料トライアルを開始
                    </Button>
                </Container>
            </Box>

            {/* Footer */}
            <Box component="footer" sx={{ backgroundColor: '#1a237e', color: '#fff', py: 6 }}>
                <Container maxWidth="lg">
                    <Grid container spacing={4}>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Typography variant="h5" fontWeight="bold" sx={{ mb: 2 }}>LogiTrace</Typography>
                            <Typography sx={{ color: 'rgba(255,255,255,0.7)', mb: 2 }}>
                                運送業のコンプライアンス管理を、<br />
                                シンプルに、確実に。
                            </Typography>
                        </Grid>
                        <Grid size={{ xs: 6, md: 2 }}>
                            <Typography fontWeight="bold" sx={{ mb: 2 }}>機能</Typography>
                            <Stack spacing={1}>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>点呼記録</Typography>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>日常点検</Typography>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>運転者台帳</Typography>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>監査対応</Typography>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 6, md: 2 }}>
                            <Typography fontWeight="bold" sx={{ mb: 2 }}>サポート</Typography>
                            <Stack spacing={1}>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>導入ガイド</Typography>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>よくある質問</Typography>
                                <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)' }}>お問い合わせ</Typography>
                            </Stack>
                        </Grid>
                        <Grid size={{ xs: 12, md: 4 }}>
                            <Typography fontWeight="bold" sx={{ mb: 2 }}>お問い合わせ</Typography>
                            <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.7)', mb: 1 }}>
                                ご質問・ご相談はお気軽にどうぞ
                            </Typography>
                            <Button
                                component={Link}
                                to="/register"
                                variant="outlined"
                                sx={{
                                    borderColor: 'rgba(255,255,255,0.5)',
                                    color: 'white',
                                    '&:hover': { borderColor: 'white', bgcolor: 'rgba(255,255,255,0.1)' }
                                }}
                            >
                                無料相談
                            </Button>
                        </Grid>
                    </Grid>
                    <Box sx={{ borderTop: '1px solid rgba(255,255,255,0.1)', mt: 6, pt: 4, textAlign: 'center' }}>
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.5)' }}>
                            &copy; 2026 LogiTrace. All rights reserved.
                        </Typography>
                    </Box>
                </Container>
            </Box>
        </>
    );
}

function FeatureCard({ icon, title, description, tags }: { icon: React.ReactNode, title: string, description: string, tags: string[] }) {
    return (
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
            <Card sx={{
                height: '100%',
                borderRadius: 3,
                boxShadow: '0 2px 12px rgba(0,0,0,0.06)',
                transition: 'transform 0.2s, box-shadow 0.2s',
                '&:hover': {
                    transform: 'translateY(-4px)',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                }
            }}>
                <CardContent sx={{ p: 3 }}>
                    <Box sx={{ mb: 2 }}>{icon}</Box>
                    <Typography variant="h6" fontWeight="bold" sx={{ mb: 1 }}>
                        {title}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                        {description}
                    </Typography>
                    <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                        {tags.map((tag, index) => (
                            <Chip key={index} label={tag} size="small" variant="outlined" sx={{ fontSize: '0.7rem' }} />
                        ))}
                    </Stack>
                </CardContent>
            </Card>
        </Grid>
    );
}

function FeatureItem({ label, active = true }: { label: string, active?: boolean }) {
    return (
        <Box component="li" sx={{ display: 'flex', alignItems: 'center', mb: 1.5, color: active ? 'text.primary' : 'text.disabled' }}>
            {active ? (
                <CheckCircleOutline color="primary" sx={{ mr: 1, fontSize: 20 }} />
            ) : (
                <HighlightOff color="disabled" sx={{ mr: 1, fontSize: 20 }} />
            )}
            <Typography variant="body2">{label}</Typography>
        </Box>
    );
}
