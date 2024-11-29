import re
import os
import argparse
import csv
import sqlite3
from datetime import datetime
import zipfile
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders


def attach_file(attachment_path, msg):
    attachment_name = attachment_path.split("/")[-1]
    attachment = open(attachment_path, "rb")
    part = MIMEBase('application', 'octet-stream')
    part.set_payload(attachment.read())
    encoders.encode_base64(part)
    part.add_header('Content-Disposition', f'attachment; filename= {attachment_name}')
    msg.attach(part)
    return msg


def send_mail(call_records, output_path, media_dir, folder_date, session_id,emails):
    # Email content
    from_email = 'dobariyamansvi@gmail.com'
    password = 'mxiz iijz wahs tuxl'
    to_email = 'manasvi@awaaz.de'
    subject = 'CAI call Log'

    # Create message
    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = emails
    msg['Subject'] = subject

    formatted_data = "\n".join([f"{key}: {value}" for key, value in call_records.items()])
    msg.attach(MIMEText(formatted_data, 'plain'))

    msg = attach_file(output_path, msg)
    msg = attach_file(media_dir + folder_date + "/" + session_id + ".csv", msg)

    try:
        # Establish a secure session with Gmail's outgoing SMTP server using your gmail account
        server = smtplib.SMTP('smtp.gmail.com', 587)
        server.starttls()  # Enable TLS encryption
        server.login(from_email, password)  # Log in to your Gmail account

        # Send email
        server.sendmail(from_email, emails.split(","), msg.as_string())
        server.quit()  # Terminate the SMTP session

        print("Email sent successfully!")
    except Exception as e:
        print("Email failed to send.")
        print(e)


def zip_folder(folder_path, output_path):
    with zipfile.ZipFile(output_path, 'w') as zip_file:
        for foldername, subfolders, filenames in os.walk(folder_path):
            for filename in filenames:
                file_path = os.path.join(foldername, filename)
                arcname = os.path.relpath(file_path, folder_path)
                zip_file.write(file_path, arcname)


def grep_line(remote_file, search_term):
    """Greps a line in a file in a directory in Python.

    Args:
        remote_file: The remote file to search.
        search_term: The search term to look for.

    Returns:
        A list of the lines in the file that contain the search term.
    """
    matching_lines = []
    try:
        with open(remote_file, "r") as log_file:
            # Read each line in the log file
            lines = log_file.readlines()

            # Iterate through the lines and find those containing the search term
            for line in lines:
                if search_term in line:
                    matching_lines.append(line)
    except Exception as e:
        print(e)
    return matching_lines


def get_responses(lines, stt, tts):
    idx = 1
    responses = {}
    for line in lines:
        if "File Recording ENDED - " in line:
            response_key = str(idx)
            responses[response_key] = {"stt_file": None, "stt_latency": None, "stt_output": None, "nlu_input": None,
                                       "nlu_latency": None, "nlu_output": None, "intent": None, "tts_input": None,
                                       "tts_latency": None, "tts_file": None,"file_recording_sec":None}
            idx += 1
            user_response_file_path = line.split("File Recording ENDED - ")[-1].strip()
            if stt:
                responses[response_key]["stt_file"] = os.path.basename(user_response_file_path)
            else:
                responses[response_key]["nlu_input"] = os.path.basename(user_response_file_path)
        elif "File Recording TIME TAKEN - " in line:
            responses[response_key]["file_recording_sec"] = line.split("File Recording TIME TAKEN - ")[-1].strip()
        elif "STT ENDED " in line:
            if stt:
                responses[response_key]["stt_output"] = line.split("STT ENDED ")[-1].strip()
        elif "STT TIME TAKEN(seconds) " in line:
            responses[response_key]["stt_latency"] = line.split("STT TIME TAKEN(seconds) ")[-1].strip()
        elif "GDF PROCESS ENDED " in line:
            if tts:
                responses[response_key]["tts_input"] = os.path.basename(line.split("GDF PROCESS ENDED ")[-1].strip())
            responses[response_key]["nlu_output"] = os.path.basename(line.split("GDF PROCESS ENDED ")[-1].strip())
        elif "GDF API TIME TAKEN(seconds) " in line:
            responses[response_key]["nlu_latency"] = line.split("GDF API TIME TAKEN(seconds) ")[-1].strip()
        if idx >= 2:
            if "DISPLAY_NAME: " in line:
                responses[response_key]["intent"] = line.split("DISPLAY_NAME: ")[-1].strip()

    return responses


def create_file(file_path=".", file_name="call_logs", overwrite=False):
    if not os.path.exists('{}/{}.csv'.format(file_path, file_name)) or overwrite:
        headers_list = ["Round", "STT file", "STT latency", "STT output", "NLU input", "NLU latency", "NLU output",
                        "Intent", "TTS input", "TTS latency", "TTS file","File recording time(sec)"]
        with open('{}/{}.csv'.format(file_path, file_name), 'w') as output_file:
            writer = csv.writer(output_file)
            writer.writerow(headers_list)


def write_or_append_to_csv(data, file_path=".", file_name="call_logs", append=True):
    if data:
        write_append_mode = 'a' if append else 'w'
        with open('{}/{}.csv'.format(file_path, file_name), write_append_mode) as output_file:
            writer = csv.writer(output_file)
            writer.writerows(data)


def get_call_records(session_id):
    conn = sqlite3.connect('/home/awaazde/www/awaazde.awaazde2/backend/awaazde/ivr/freeswitch/lua/common/integrations/test/cai.db')
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM cai_call_records WHERE call_uuid = ?', (session_id,))
    matching_record = cursor.fetchone()
    matching_dict = {}
    if matching_record:
        column_names = [description[0] for description in cursor.description]
        matching_dict = dict(zip(column_names, matching_record))

    # Close the cursor and connection
    cursor.close()
    conn.close()

    return matching_dict

def add_cai_call_logs_to_db(data):
    conn = sqlite3.connect('/home/awaazde/www/awaazde.awaazde2/backend/awaazde/ivr/freeswitch/lua/common/integrations/test/cai.db')
    cursor = conn.cursor()
    insert_logs_query = '''
        INSERT INTO cai_call_logs
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    '''
    # Execute the insert query for each row in the data
    cursor.executemany(insert_logs_query, data)
    conn.commit()
    conn.close()


# Initialize parser
parser = argparse.ArgumentParser()

# Adding optional argument
parser.add_argument("-tt", "--tts", type=lambda x: (str(x).lower() == 'true'), help="tts or not boolean value",
                    required=True)
parser.add_argument("-st", "--stt", type=lambda x: (str(x).lower() == 'true'), help="stt or not boolean value",
                    required=True)
parser.add_argument("-d", "--date", help="Date used to check logs passed in YYYY-MM-DD format", required=True)
parser.add_argument("-s", "--search", help="search term", required=True)
parser.add_argument("-e","--email",help="Comma separated emails",required=True)
# Read arguments from command line
args = parser.parse_args()

media_dir = "/home/awaazde/www/awaazde.awaazde2/media/ad_abcde/freeswitch/"
remote_dir = "/home/awaazde/log/lua"
remote_file = remote_dir + "/awaazde_" + args.date + ".log"
session_id = args.search
stt = args.stt
tts = args.tts
emails = args.email
date_object = datetime.strptime(args.date, "%Y-%m-%d")
folder_date = date_object.strftime("%Y/%m/%d")
audio_folder_path = media_dir + folder_date + "/" + session_id
call_records = get_call_records(session_id)
print(call_records)
lines = grep_line(remote_file, session_id)

if not lines:
    raise Exception('Either file not found or file is empty')

responses = get_responses(lines, stt, tts)
print(responses)
details = []
sqlite_data = []
for r, v in responses.items():
    tmp = [r, v['stt_file'], v['stt_latency'], v['stt_output'], v['nlu_input'], v['nlu_latency'], v['nlu_output'],
           v['intent'], v['tts_input'], v['tts_latency'], v['tts_file'], v['file_recording_sec']]
    details.append(tmp)
    sqlite_data.append((session_id,r,v['stt_file'], v['stt_latency'], v['stt_output'], v['nlu_input'], v['nlu_latency'], v['nlu_output'],
           v['intent'], v['tts_input'], v['tts_latency'], v['tts_file'],v['file_recording_sec']))

print(sqlite_data)
create_file(file_path=media_dir + folder_date + "/", file_name=session_id)
write_or_append_to_csv(details, file_path=media_dir + folder_date + "/", file_name=session_id)
add_cai_call_logs_to_db(sqlite_data)
output_path = audio_folder_path + ".zip"
zip_folder(audio_folder_path, output_path)
send_mail(call_records, output_path, media_dir, folder_date, session_id,emails)
