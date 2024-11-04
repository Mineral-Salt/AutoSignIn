
import datetime
try:
    from chinese_calendar import is_workday
except ImportError:
    print("Library 'chinesecalendar' is not installed.")
    exit(1)

today = datetime.date.today()

try:
    if is_workday(today):
        print("true")
        exit(0)
    else:
        print("false")
        exit(0)
except NotImplementedError:
    print("Library 'chinesecalendar' is old.")
    exit(2)
