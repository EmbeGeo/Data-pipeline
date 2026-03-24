# z_score.py
import math
from collections import deque
from .base import BaseFilter

class ZScoreFilter(BaseFilter):
    """
    Z-Score(표준점수) 기반 이상치 탐지 알고리즘.
    
    데이터가 정규분포를 따른다고 가정하고, 새로운 값이 평균으로부터 
    표준편차의 몇 배만큼 떨어져있는지(Z값)를 구하여 이상치를 감지합니다.
    """
    def __init__(self, data_fields, window_size=10, threshold=3.0):
        self.history = {field: deque(maxlen=window_size) for field in data_fields}
        self.threshold = threshold

    def process(self, field, value):
        history_queue = self.history[field]
        
        # 분산(Variance)과 표준편차를 구하려면 데이터가 최소 2개는 있어야 합니다.
        if len(history_queue) < 2:
            history_queue.append(value)
            return True
            
        # 평균 계산
        mean = sum(history_queue) / len(history_queue)
        
        # 분산 차 및 표준편차 계산
        variance = sum((x - mean) ** 2 for x in history_queue) / len(history_queue)
        std_dev = math.sqrt(variance)
        
        # 과거 데이터가 전부 똑같아서 표준편차가 0인 경우 0으로 나누기 에러 방지
        if std_dev == 0:
            if value != mean:
                # 당장 이전 값들과 다르다고 다 이상치는 아니므로 일단 큐에 넣고 통과 (유연하게 적용)
                history_queue.append(value)
            return True
            
        # Z-Score 공식: |x - 평균| / 표준편차
        z_score = abs(value - mean) / std_dev
        
        if z_score > self.threshold:
            print(f"  └ [Z-Score 🚫]   {field} 튀는 값 탐지 - Z점수 넘음: Z={z_score:.2f} (Threshold={self.threshold})")
            return False
            
        # 정상 데이터면 저장
        history_queue.append(value)
        return True
