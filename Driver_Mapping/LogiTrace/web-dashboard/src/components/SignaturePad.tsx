import { useRef, useEffect, useState } from 'react';
import {
    Box,
    Button,
    Paper,
    Typography,
    Stack,
} from '@mui/material';
import {
    Clear as ClearIcon,
    Check as CheckIcon,
} from '@mui/icons-material';

interface SignaturePadProps {
    onSignatureChange: (signatureData: string | null) => void;
    width?: number;
    height?: number;
    label?: string;
    initialSignature?: string | null;
}

const SignaturePad = ({
    onSignatureChange,
    width = 400,
    height = 200,
    label = '電子署名',
    initialSignature = null,
}: SignaturePadProps) => {
    const canvasRef = useRef<HTMLCanvasElement>(null);
    const [isDrawing, setIsDrawing] = useState(false);
    const [hasSignature, setHasSignature] = useState(false);

    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        if (!ctx) return;

        // 背景を白に設定
        ctx.fillStyle = '#fff';
        ctx.fillRect(0, 0, width, height);

        // 初期署名がある場合は表示
        if (initialSignature) {
            const img = new Image();
            img.onload = () => {
                ctx.drawImage(img, 0, 0);
                setHasSignature(true);
            };
            img.src = initialSignature;
        }

        // 署名線のスタイル
        ctx.strokeStyle = '#000';
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
    }, [width, height, initialSignature]);

    const getCoordinates = (e: React.MouseEvent | React.TouchEvent) => {
        const canvas = canvasRef.current;
        if (!canvas) return { x: 0, y: 0 };

        const rect = canvas.getBoundingClientRect();
        const scaleX = canvas.width / rect.width;
        const scaleY = canvas.height / rect.height;

        if ('touches' in e) {
            const touch = e.touches[0];
            return {
                x: (touch.clientX - rect.left) * scaleX,
                y: (touch.clientY - rect.top) * scaleY,
            };
        } else {
            return {
                x: (e.clientX - rect.left) * scaleX,
                y: (e.clientY - rect.top) * scaleY,
            };
        }
    };

    const startDrawing = (e: React.MouseEvent | React.TouchEvent) => {
        e.preventDefault();
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d');
        if (!ctx) return;

        setIsDrawing(true);
        const { x, y } = getCoordinates(e);
        ctx.beginPath();
        ctx.moveTo(x, y);
    };

    const draw = (e: React.MouseEvent | React.TouchEvent) => {
        e.preventDefault();
        if (!isDrawing) return;

        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d');
        if (!ctx) return;

        const { x, y } = getCoordinates(e);
        ctx.lineTo(x, y);
        ctx.stroke();
        setHasSignature(true);
    };

    const stopDrawing = () => {
        setIsDrawing(false);

        // 署名データを親コンポーネントに渡す
        if (hasSignature) {
            const canvas = canvasRef.current;
            if (canvas) {
                const signatureData = canvas.toDataURL('image/png');
                onSignatureChange(signatureData);
            }
        }
    };

    const clearSignature = () => {
        const canvas = canvasRef.current;
        const ctx = canvas?.getContext('2d');
        if (!ctx || !canvas) return;

        ctx.fillStyle = '#fff';
        ctx.fillRect(0, 0, width, height);
        setHasSignature(false);
        onSignatureChange(null);
    };

    const confirmSignature = () => {
        const canvas = canvasRef.current;
        if (canvas && hasSignature) {
            const signatureData = canvas.toDataURL('image/png');
            onSignatureChange(signatureData);
        }
    };

    return (
        <Paper sx={{ p: 2 }}>
            <Typography variant="subtitle2" gutterBottom>
                {label}
            </Typography>
            <Box
                sx={{
                    border: '2px dashed #ccc',
                    borderRadius: 1,
                    overflow: 'hidden',
                    touchAction: 'none',
                    mb: 1,
                }}
            >
                <canvas
                    ref={canvasRef}
                    width={width}
                    height={height}
                    style={{
                        width: '100%',
                        height: 'auto',
                        cursor: 'crosshair',
                        display: 'block',
                    }}
                    onMouseDown={startDrawing}
                    onMouseMove={draw}
                    onMouseUp={stopDrawing}
                    onMouseLeave={stopDrawing}
                    onTouchStart={startDrawing}
                    onTouchMove={draw}
                    onTouchEnd={stopDrawing}
                />
            </Box>
            <Stack direction="row" spacing={1} justifyContent="flex-end">
                <Button
                    size="small"
                    variant="outlined"
                    startIcon={<ClearIcon />}
                    onClick={clearSignature}
                >
                    クリア
                </Button>
                <Button
                    size="small"
                    variant="contained"
                    startIcon={<CheckIcon />}
                    onClick={confirmSignature}
                    disabled={!hasSignature}
                >
                    確定
                </Button>
            </Stack>
            <Typography variant="caption" color="textSecondary" sx={{ mt: 1, display: 'block' }}>
                上のエリアにマウスまたは指で署名してください
            </Typography>
        </Paper>
    );
};

export default SignaturePad;
