
def write_to_csv(file_path, df):
    df = df.drop("hours", axis=1)
    df["asset"] = df["asset"].apply(lambda x: x.get('id'))

    df.to_csv(file_path)
    return
