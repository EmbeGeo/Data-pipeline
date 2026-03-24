# base.py
class BaseFilter:
    """모든 필터가 공통으로 상속받아야 하는 베이스 인터페이스"""
    
    def process(self, field: str, value: float) -> bool:
        """
        :param field: 어떤 센서 필드인지 (예: 'data_01')
        :param value: 현재 확인할 값
        :return: 정상치이면 True, 이상치이면 False를 리턴합니다.
        """
        raise NotImplementedError("BaseFilter를 상속받는 하위 클래스에서 이 메서드를 구현해야 합니다.")
