# moving_average.py
from collections import deque
from .base import BaseFilter

class MovingAverageFilter(BaseFilter):
    """
    이동 평균(Moving Average) 기반 이상치 탐지
    이전 윈도우(Window) 사이즈 만큼의 데이터 평균을 구하고, 
    새로 들어온 값이 그 평균으로부터 허용범위를 넘어서면 이상치로 판별.
    """
    def __init__(self, data_fields, window_size=5, max_deviation=40.0):
        # deque(maxlen)을 활용하여 항상 최신 데이터 N개만 유지하도록 설계
        self.history = {field: deque(maxlen=window_size) for field in data_fields}
        self.max_deviation = max_deviation

    def process(self, field, value):
        history_queue = self.history[field]
        
        # 아직 큐가 비어있으면 비교할 대상이 없으므로 정상 처리
        if not history_queue:
            history_queue.append(value)
            return True
            
        # 평균 계산
        moving_average = sum(history_queue) / len(history_queue)
        deviation = abs(value - moving_average)
        
        # 허용 오차 이상 벗어나면
        if deviation > self.max_deviation:
            print(f"  └ [MovingAvg 🚫] {field} 오인식 탐지 - 평균: {moving_average:.1f}, 입력값: {value:.1f} (오차: {deviation:.1f} > {self.max_deviation})")
            return False
            
        # 정상 값이면 큐에 차곡차곡 쌓음
        history_queue.append(value)
        return True
