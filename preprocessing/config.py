# config.py
# 배열 설정 및 필터링할 센서 변수 정의

# 14개의 데이터 필드 이름 지정
DATA_FIELDS = [f"data_{i:02d}" for i in range(1, 15)]

# 이동평균(Moving Average) 필터 설정
MA_WINDOW_SIZE = 5         # 이전 5개의 데이터 평균을 구함
MA_MAX_DEVIATION = 40.0    # 평균에서 40.0 이상 벗어나면 이상치 처리

# Z-Score (표준점수) 이상치 탐지 설정
Z_WINDOW_SIZE = 10         # 표준편차 및 평균을 구할 이전 데이터 개수
Z_SCORE_THRESHOLD = 3.0    # Z-Score가 이 값을 넘으면 이상치 (보통 3.0 사용)

# 절대 범위 필터 설정

ABSOLUTE_MIN = -50.0       # 이 값이하로 떨어지면 아예 센서 오류로 취급
ABSOLUTE_MAX = 500.0       # 이 값을 넘으면 아예 센서 오류로 취급
