import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Modal,
  TextInput,
  ScrollView,
  Alert
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { BreakRecord } from '../config/industryFields';

interface BreakRecordInputProps {
  value: BreakRecord[];
  onChange: (records: BreakRecord[]) => void;
  disabled?: boolean;
}

const BreakRecordInput: React.FC<BreakRecordInputProps> = ({
  value = [],
  onChange,
  disabled = false
}) => {
  const [modalVisible, setModalVisible] = useState(false);
  const [editingRecord, setEditingRecord] = useState<BreakRecord | null>(null);
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  const [location, setLocation] = useState('');
  const [reason, setReason] = useState('');

  const generateId = () => {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  };

  const formatTime = (time: string): string => {
    // Remove non-numeric characters except colon
    const cleaned = time.replace(/[^\d:]/g, '');

    // Auto-format as HH:MM
    if (cleaned.length === 4 && !cleaned.includes(':')) {
      return cleaned.slice(0, 2) + ':' + cleaned.slice(2);
    }
    return cleaned;
  };

  const validateTime = (time: string): boolean => {
    const regex = /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/;
    return regex.test(time);
  };

  const openAddModal = () => {
    setEditingRecord(null);
    setStartTime('');
    setEndTime('');
    setLocation('');
    setReason('');
    setModalVisible(true);
  };

  const openEditModal = (record: BreakRecord) => {
    setEditingRecord(record);
    setStartTime(record.startTime);
    setEndTime(record.endTime);
    setLocation(record.location);
    setReason(record.reason || '');
    setModalVisible(true);
  };

  const handleSave = () => {
    // Validate
    if (!validateTime(startTime) || !validateTime(endTime)) {
      Alert.alert('入力エラー', '時刻は HH:MM 形式で入力してください');
      return;
    }
    if (!location.trim()) {
      Alert.alert('入力エラー', '場所を入力してください');
      return;
    }

    const newRecord: BreakRecord = {
      id: editingRecord?.id || generateId(),
      startTime,
      endTime,
      location: location.trim(),
      reason: reason.trim() || undefined
    };

    if (editingRecord) {
      // Update existing record
      const updatedRecords = value.map(r =>
        r.id === editingRecord.id ? newRecord : r
      );
      onChange(updatedRecords);
    } else {
      // Add new record
      onChange([...value, newRecord]);
    }

    setModalVisible(false);
  };

  const handleDelete = (recordId: string) => {
    Alert.alert(
      '削除確認',
      'この休憩記録を削除しますか？',
      [
        { text: 'キャンセル', style: 'cancel' },
        {
          text: '削除',
          style: 'destructive',
          onPress: () => {
            onChange(value.filter(r => r.id !== recordId));
          }
        }
      ]
    );
  };

  const calculateDuration = (start: string, end: string): string => {
    try {
      const [startH, startM] = start.split(':').map(Number);
      const [endH, endM] = end.split(':').map(Number);

      let duration = (endH * 60 + endM) - (startH * 60 + startM);
      if (duration < 0) duration += 24 * 60; // Next day

      const hours = Math.floor(duration / 60);
      const minutes = duration % 60;

      if (hours > 0) {
        return `${hours}時間${minutes > 0 ? minutes + '分' : ''}`;
      }
      return `${minutes}分`;
    } catch {
      return '';
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.label}>休憩記録</Text>
        {!disabled && (
          <TouchableOpacity style={styles.addButton} onPress={openAddModal}>
            <Ionicons name="add-circle" size={24} color="#007AFF" />
            <Text style={styles.addButtonText}>追加</Text>
          </TouchableOpacity>
        )}
      </View>

      {value.length === 0 ? (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>休憩記録がありません</Text>
        </View>
      ) : (
        <View style={styles.recordsList}>
          {value.map((record, index) => (
            <View key={record.id} style={styles.recordItem}>
              <View style={styles.recordInfo}>
                <View style={styles.recordTimeRow}>
                  <Ionicons name="time-outline" size={16} color="#666" />
                  <Text style={styles.recordTime}>
                    {record.startTime} - {record.endTime}
                  </Text>
                  <Text style={styles.recordDuration}>
                    ({calculateDuration(record.startTime, record.endTime)})
                  </Text>
                </View>
                <View style={styles.recordLocationRow}>
                  <Ionicons name="location-outline" size={16} color="#666" />
                  <Text style={styles.recordLocation}>{record.location}</Text>
                </View>
                {record.reason && (
                  <Text style={styles.recordReason}>備考: {record.reason}</Text>
                )}
              </View>
              {!disabled && (
                <View style={styles.recordActions}>
                  <TouchableOpacity
                    style={styles.actionButton}
                    onPress={() => openEditModal(record)}
                  >
                    <Ionicons name="pencil" size={18} color="#007AFF" />
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={styles.actionButton}
                    onPress={() => handleDelete(record.id)}
                  >
                    <Ionicons name="trash-outline" size={18} color="#FF3B30" />
                  </TouchableOpacity>
                </View>
              )}
            </View>
          ))}
        </View>
      )}

      <Modal
        visible={modalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setModalVisible(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>
                {editingRecord ? '休憩記録を編集' : '休憩記録を追加'}
              </Text>
              <TouchableOpacity onPress={() => setModalVisible(false)}>
                <Ionicons name="close" size={24} color="#333" />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody}>
              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>開始時刻 *</Text>
                <TextInput
                  style={styles.input}
                  value={startTime}
                  onChangeText={(text) => setStartTime(formatTime(text))}
                  placeholder="10:30"
                  keyboardType="numbers-and-punctuation"
                  maxLength={5}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>終了時刻 *</Text>
                <TextInput
                  style={styles.input}
                  value={endTime}
                  onChangeText={(text) => setEndTime(formatTime(text))}
                  placeholder="10:45"
                  keyboardType="numbers-and-punctuation"
                  maxLength={5}
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>場所 *</Text>
                <TextInput
                  style={styles.input}
                  value={location}
                  onChangeText={setLocation}
                  placeholder="〇〇SA、△△PA など"
                />
              </View>

              <View style={styles.inputGroup}>
                <Text style={styles.inputLabel}>備考</Text>
                <TextInput
                  style={[styles.input, styles.textArea]}
                  value={reason}
                  onChangeText={setReason}
                  placeholder="任意"
                  multiline
                  numberOfLines={2}
                />
              </View>
            </ScrollView>

            <View style={styles.modalFooter}>
              <TouchableOpacity
                style={styles.cancelButton}
                onPress={() => setModalVisible(false)}
              >
                <Text style={styles.cancelButtonText}>キャンセル</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.saveButton} onPress={handleSave}>
                <Text style={styles.saveButtonText}>保存</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginVertical: 8,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  addButton: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  addButtonText: {
    color: '#007AFF',
    marginLeft: 4,
    fontSize: 14,
  },
  emptyState: {
    padding: 16,
    backgroundColor: '#F5F5F5',
    borderRadius: 8,
    alignItems: 'center',
  },
  emptyText: {
    color: '#999',
    fontSize: 14,
  },
  recordsList: {
    gap: 8,
  },
  recordItem: {
    flexDirection: 'row',
    backgroundColor: '#F5F5F5',
    borderRadius: 8,
    padding: 12,
  },
  recordInfo: {
    flex: 1,
  },
  recordTimeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 4,
  },
  recordTime: {
    fontSize: 15,
    fontWeight: '500',
    color: '#333',
  },
  recordDuration: {
    fontSize: 13,
    color: '#666',
  },
  recordLocationRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  recordLocation: {
    fontSize: 14,
    color: '#333',
  },
  recordReason: {
    fontSize: 13,
    color: '#666',
    marginTop: 4,
    marginLeft: 20,
  },
  recordActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  actionButton: {
    padding: 4,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#FFF',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  modalBody: {
    padding: 16,
  },
  inputGroup: {
    marginBottom: 16,
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '500',
    color: '#333',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#FFF',
  },
  textArea: {
    minHeight: 60,
    textAlignVertical: 'top',
  },
  modalFooter: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
    borderTopWidth: 1,
    borderTopColor: '#E0E0E0',
  },
  cancelButton: {
    flex: 1,
    padding: 14,
    borderRadius: 8,
    backgroundColor: '#F5F5F5',
    alignItems: 'center',
  },
  cancelButtonText: {
    fontSize: 16,
    fontWeight: '500',
    color: '#666',
  },
  saveButton: {
    flex: 1,
    padding: 14,
    borderRadius: 8,
    backgroundColor: '#007AFF',
    alignItems: 'center',
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#FFF',
  },
});

export default BreakRecordInput;
